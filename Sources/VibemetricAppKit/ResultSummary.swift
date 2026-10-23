import SwiftUI
import VibemetricCore

/// The first screen of a result: the score, what's going well, and what to fix, one short box per category.
/// Each category opens its full explanation, evidence and steps with "See details".
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
                Text(RelativeDate.format(record.createdAt, now: context.date))
                    .foregroundStyle(Theme.muted)
                    .scaledFont(13)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(card.totalLabel ?? "—").scaledFont(56, weight: .semibold).foregroundStyle(Theme.ink)
                    Text("/ 100").scaledFont(20).foregroundStyle(Theme.muted)
                }
                if let baseline, let delta = ScoreChanges.totalDelta(card, to: baseline.card) {
                    ChangePill(delta: delta, since: baseline.createdAt)
                }
            }
        }
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

/// One category: a centered banner with its name and score, the issue and the fix side by side, and "See details",
/// which opens the full explanation. A click anywhere on the box does the same.
private struct FixBox: View {
    var result: ScoreCard.DimensionResult
    var change: ScoreChange?
    var note: String?
    var deductions: [ScoreCard.Deduction]
    var footer: AnyView?
    var expandAll: Bool
    @State private var expanded: Bool

    init(result: ScoreCard.DimensionResult, change: ScoreChange?, note: String?, deductions: [ScoreCard.Deduction],
         footer: AnyView?, expanded: Bool) {
        self.result = result
        self.change = change
        self.note = note
        self.deductions = deductions
        self.footer = footer
        self.expandAll = expanded
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

    private var bandColor: Color { result.band.map(Theme.color(for:)) ?? Theme.muted }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) { summary.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityHint(expanded ? "Hides the details" : "Shows the details")
            if expanded {
                divider
                CategoryDetails(result: result, note: note, deductions: deductions, footer: footer, expandAll: expandAll)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            divider
            // "See details" across the bottom, tinted in the score's band color; unscored categories stay neutral.
            Button(action: toggle) {
                Label {
                    Text(expanded ? "Hide details" : "See details")
                } icon: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                    .labelStyle(TrailingIconLabelStyle())
                    .scaledFont(13, weight: .semibold)
                    .foregroundStyle(bandColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(result.band.map { Theme.color(for: $0).opacity(0.16) } ?? Theme.paper)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointingHandCursor()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.rule, lineWidth: 1))
    }

    private func toggle() { withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() } }

    private var divider: some View {
        Rectangle().fill(result.band.map { Theme.color(for: $0).opacity(0.3) } ?? Theme.rule).frame(height: 1)
    }

    private var summary: some View {
        VStack(spacing: 0) {
            // A centered banner: the name, then the score as dots and "6/10".
            VStack(spacing: 5) {
                Text(result.dimension.title).scaledFont(15, weight: .semibold).foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    ScorePips(score: result.score, size: 9)
                    Text(result.score.map { "\($0)/10" } ?? result.status.label)
                        .scaledFont(15, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(bandColor)
                    if let change { DeltaBadge(change: change) }
                }
            }
            .multilineTextAlignment(.center)
            .padding(.vertical, 11)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            divider
            // Issue and fix side by side, split by a thin rule.
            HStack(alignment: .top, spacing: 0) {
                column(label: "Issue", text: issue, color: Theme.color(for: .bottleneck))
                if let fix {
                    Rectangle().fill(Theme.rule).frame(width: 1).padding(.vertical, 2)
                    column(label: "Fix", text: fix, color: Theme.color(for: .strong))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 12)
        }
        .accessibilityElement(children: .combine)
    }

    private func column(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).scaledFont(13, weight: .semibold).foregroundStyle(color)
            Text(inline(text)).scaledFont(14).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// The change in the total since the previous score, e.g. "↑ 7 since Oct 20": green up, red down, grey unchanged.
private struct ChangePill: View {
    var delta: Int
    var since: Date

    private var color: Color {
        delta > 0 ? Theme.color(for: .strong) : delta < 0 ? Theme.color(for: .bottleneck) : Theme.muted
    }
    private var text: String {
        let date = since.formatted(.dateTime.month(.abbreviated).day())
        if delta == 0 { return "No change since \(date)" }
        return "\(delta > 0 ? "↑" : "↓") \(abs(delta)) since \(date)"
    }

    var body: some View {
        Text(text)
            .scaledFont(12, weight: .semibold)
            .monospacedDigit()
            .padding(.horizontal, 10).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// The title, then its icon: "See details ⌄".
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.title
            configuration.icon
        }
    }
}

private extension View {
    /// The pointing-hand cursor while the pointer is over this view, as for a link.
    func pointingHandCursor() -> some View {
        onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
