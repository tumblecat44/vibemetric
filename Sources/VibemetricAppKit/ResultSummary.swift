import SwiftUI
import VibemetricCore

/// The first screen of a result: the score, what's going well, and what to fix, one short box per category.
/// The full explanations, evidence and steps sit below it in `ReadableCardContent`, behind "See all 10 categories".
struct ResultSummary: View {
    @Environment(\.textScale) private var scale
    var record: CardRecord
    var baseline: CardRecord?
    var changes: [ScoreChange] = []
    /// Opens every box (shared and exported cards).
    var expandAll = false
    var deepDiveFooter: ((VibemetricCore.Dimension) -> AnyView)?
    @State private var showsAllFixes = false

    /// Boxes shown before "Show more".
    static let visibleFixes = 10

    private var card: ScoreCard { record.card }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            score
            if !highlights.isEmpty { doingWell }
            if !fixes.isEmpty { toFix }
        }
    }

    // MARK: Score

    private var score: some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 6) {
                    Text("Your AI Native Score · \(RelativeDate.format(record.createdAt, now: context.date)) · from \(card.scope.sessionsExamined) sessions")
                        .foregroundStyle(Theme.muted)
                    if let baseline, let delta = ScoreChanges.totalDelta(card, to: baseline.card), delta != 0 {
                        Text("· \(delta > 0 ? "↗ +" : "↘ ")\(delta) since \(baseline.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                            .fontWeight(.semibold)
                            .foregroundStyle(delta > 0 ? Theme.color(for: .strong) : Theme.color(for: .bottleneck))
                    }
                }
                .scaledFont(13)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(card.totalLabel ?? "—").scaledFont(56, weight: .semibold).foregroundStyle(Theme.ink)
                    Text("/ 100").scaledFont(20).foregroundStyle(Theme.muted)
                }
                if let band = overallBand { BandPill(band: band) }
            }
            if card.isLowCoverage(sessionsAvailable: record.sessionsScanned) {
                Label("Few sessions were examined, so this score may miss evidence.", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(12)
                    .foregroundStyle(Theme.color(for: .developing))
            }
        }
    }

    /// The total's band on the same 0–10 scale as a category: 68 → 6.8 → developing.
    private var overallBand: Band? {
        guard card.totalLabel != nil, card.unknownCount < VibemetricCore.Dimension.allCases.count else { return nil }
        return Band(score: card.knownTotal / 10)
    }

    // MARK: What you're doing well

    /// The card's own one-liners, or on older cards the headlines of its best categories.
    private var highlights: [String] {
        if let lines = card.highlights?.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }), !lines.isEmpty { return lines }
        return Array(card.ordered.filter { ($0.score ?? 0) >= 7 }
            .sorted { ($0.score ?? 0) > ($1.score ?? 0) }
            .prefix(3)
            .map(\.headline))
    }

    private var doingWell: some View {
        VStack(alignment: .leading, spacing: 8) {
            SummaryHeading(text: "What you're doing well", symbol: "checkmark.circle", color: Theme.color(for: .strong))
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(highlights.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•").foregroundStyle(Theme.color(for: .strong))
                        Text(inline(line)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .scaledFont(15)
            .foregroundStyle(Theme.ink)
        }
    }

    // MARK: What to fix

    /// Every category, the weakest first and unscored ones last (rubric order breaks ties).
    private var fixes: [ScoreCard.DimensionResult] {
        let order = VibemetricCore.Dimension.allCases
        return card.dimensions
            .sorted { ($0.score ?? 11, order.firstIndex(of: $0.dimension) ?? 0) < ($1.score ?? 11, order.firstIndex(of: $1.dimension) ?? 0) }
    }

    private var toFix: some View {
        let shown = showsAllFixes ? fixes : Array(fixes.prefix(Self.visibleFixes))
        let hidden = fixes.dropFirst(Self.visibleFixes)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                SummaryHeading(text: "What to fix", symbol: "exclamationmark.triangle", color: Theme.color(for: .developing))
                if fixes.count > Self.visibleFixes {
                    Text("· \(shown.count) of \(fixes.count)").scaledFont(13).foregroundStyle(Theme.muted)
                }
            }
            ForEach(shown) { d in
                FixBox(result: d, change: changes.first { $0.dimension == d.dimension },
                       note: card.deductionNote(for: d.dimension),
                       deductions: card.deductionAppliedTo == d.dimension ? card.deductions ?? [] : [],
                       footer: deepDiveFooter?(d.dimension), expanded: expandAll)
            }
            if !hidden.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showsAllFixes.toggle() }
                } label: {
                    Label(showsAllFixes ? "Show fewer" : "Show \(hidden.count) more · \(hidden.map(\.dimension.title).joined(separator: ", "))",
                          systemImage: showsAllFixes ? "chevron.up" : "chevron.down")
                        .scaledFont(13)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One category: a banner with its icon, name and score, then the issue and the fix in one line each.
/// A click opens the full explanation below them.
private struct FixBox: View {
    var result: ScoreCard.DimensionResult
    var change: ScoreChange?
    var note: String?
    var deductions: [ScoreCard.Deduction]
    var footer: AnyView?
    @State private var expanded: Bool

    init(result: ScoreCard.DimensionResult, change: ScoreChange?, note: String?, deductions: [ScoreCard.Deduction],
         footer: AnyView?, expanded: Bool) {
        self.result = result
        self.change = change
        self.note = note
        self.deductions = deductions
        self.footer = footer
        _expanded = State(initialValue: expanded)
    }

    /// The scorer's one-line issue. Older cards have none: their problem text's first sentence when it's between six
    /// words and about one line, which carries more context than the headline, else the headline.
    private var issue: String {
        if let line = result.issueLine, !line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
        if let first = result.saw.flatMap(Self.firstSentence), first.count <= 120,
           first.split(separator: " ").count >= 6 { return first }
        return result.headline
    }

    static func firstSentence(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var sentence = trimmed
        trimmed.enumerateSubstrings(in: trimmed.startIndex..., options: .bySentences) { substring, _, _, stop in
            if let substring { sentence = substring.trimmingCharacters(in: .whitespaces) }
            stop = true
        }
        return sentence
    }
    private var fix: String? {
        if let line = result.fixLine, !line.trimmingCharacters(in: .whitespaces).isEmpty { return line }
        return result.tryThis.flatMap { $0.isEmpty ? nil : $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                summary.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Hides the details" : "Shows the details")
            if expanded {
                Rectangle().fill(Theme.rule).frame(height: 1)
                CategoryDetails(result: result, note: note, deductions: deductions, footer: footer)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule, lineWidth: 1))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A banner across the top holds the name and score. The badge is as tall as the 16-point title's letters,
            // not its line height.
            HStack(spacing: 7) {
                CategoryBadge(dimension: result.dimension, size: 16)
                Text(result.dimension.title).scaledFont(16, weight: .semibold).foregroundStyle(Theme.ink)
                // The score right after the name.
                if let score = result.score, let band = result.band {
                    Text("\(score)/10")
                        .scaledFont(12, weight: .semibold)
                        .monospacedDigit()
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .foregroundStyle(Theme.color(for: band))
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6))
                        .padding(.leading, 3)
                }
                Spacer(minLength: 0)
                if let change { DeltaBadge(change: change) }
                Image(systemName: "chevron.right")
                    .scaledFont(12, weight: .semibold)
                    .foregroundStyle(Theme.muted)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            // Tinted in the score's band color; unscored categories keep a neutral banner.
            .background(result.band.map { Theme.color(for: $0).opacity(0.16) } ?? Theme.paper)
            .overlay(alignment: .bottom) {
                Rectangle().fill(result.band.map { Theme.color(for: $0).opacity(0.3) } ?? Theme.rule).frame(height: 1)
            }
            // A grid sizes the label column to the widest label at any text size, so both lines start at one edge,
            // flush with the box's left padding.
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 4) {
                row(label: "Issue", text: issue, color: Theme.color(for: .bottleneck))
                if let fix { row(label: "Fix", text: fix, color: Theme.color(for: .strong)) }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func row(label: String, text: String, color: Color) -> some View {
        GridRow {
            Text(label).scaledFont(12, weight: .semibold).foregroundStyle(color)
                .fixedSize()
                .gridColumnAlignment(.leading)
            Text(inline(text)).scaledFont(14).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A category's icon in a round badge: black with a white icon in light mode, white with a dark icon in dark mode.
struct CategoryBadge: View {
    @Environment(\.textScale) private var scale
    var dimension: VibemetricCore.Dimension
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle().fill(Theme.ink)
            Image(systemName: dimension.symbol)
                .font(.system(size: size * 0.45 * scale, weight: .semibold))
                .foregroundStyle(Theme.paper)
        }
        .frame(width: size * scale, height: size * scale)
        .accessibilityHidden(true)
    }
}

/// The summary's section titles: an icon in the section's color, then the title.
private struct SummaryHeading: View {
    var text: String
    var symbol: String
    var color: Color

    var body: some View {
        Label {
            Text(text).scaledFont(16, weight: .bold).foregroundStyle(Theme.ink)
        } icon: {
            Image(systemName: symbol).scaledFont(15, weight: .semibold).foregroundStyle(color)
        }
    }
}

/// The band as a small tinted label, e.g. "Developing".
private struct BandPill: View {
    var band: Band

    var body: some View {
        Text(band.rawValue.capitalized)
            .scaledFont(12, weight: .semibold)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .foregroundStyle(Theme.color(for: band))
            .background(Theme.color(for: band).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}
