import AppKit
import SwiftUI
import VibemetricCore

/// The score card for readable cards (short plain-text fields): the one fix first, then the categories as
/// rows that open on a click, and the technical details folded away at the end. Older cards keep `CardContent`'s
/// original layout.
struct ReadableCardContent: View {
    @Environment(\.textScale) private var scale
    var record: CardRecord
    var baseline: CardRecord?
    var expandAll: Bool
    var deepDiveFooter: ((VibemetricCore.Dimension) -> AnyView)?

    private var card: ScoreCard { record.card }
    private var changes: [ScoreChange] { baseline.map { ScoreChanges.compare(card, to: $0.card) } ?? [] }
    private func change(for d: VibemetricCore.Dimension) -> ScoreChange? { changes.first { $0.dimension == d } }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            header.id("header")
            fixFirst.id("improvement")
            if !glanceGood.isEmpty { glance }
            categories.id("dimensions")
            if let baseline, !changes.isEmpty { changesSection(baseline) }
            if !card.roadmap.isEmpty { roadmap.id("roadmap") }
            about.id("scope")
        }
        .scrollTargetLayout()
        .textSelection(.enabled)
        .padding(32)
        .frame(maxWidth: 820 * max(1, scale), alignment: .leading)
    }

    // MARK: Header: when, how much, and the one-sentence summary

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(RelativeDate.format(record.createdAt, now: context.date)) · from \(card.scope.sessionsExamined) sessions")
                        .foregroundStyle(Theme.muted)
                    Text("·").foregroundStyle(Theme.muted)
                    Text("Score \(card.totalLabel ?? "—") / 100").fontWeight(.semibold).foregroundStyle(Theme.ink)
                    if let baseline, let delta = ScoreChanges.totalDelta(card, to: baseline.card), delta != 0 {
                        Text("\(delta > 0 ? "↗ +" : "↘ ")\(delta) since \(baseline.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                            .fontWeight(.semibold)
                            .foregroundStyle(delta > 0 ? Theme.color(for: .strong) : Theme.color(for: .bottleneck))
                    }
                }
                .scaledFont(13)
            }
            Text(card.diagnosis)
                .scaledFont(24, weight: .bold)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if card.isLowCoverage(sessionsAvailable: record.sessionsScanned) {
                Label("Few sessions were examined, so this score may miss evidence.", systemImage: "exclamationmark.triangle.fill")
                    .scaledFont(12)
                    .foregroundStyle(Theme.color(for: .developing))
            }
        }
    }

    // MARK: What to fix: the first fix, then the other weak categories, one page at a time

    private var fixFirst: some View { FixCarousel(card: card) }

    // MARK: At a glance: the best and weakest categories, one line each

    private var scored: [ScoreCard.DimensionResult] { card.ordered.filter { $0.score != nil } }
    private var glanceGood: [ScoreCard.DimensionResult] {
        Array(scored.filter { ($0.score ?? 0) >= 6 }.sorted { ($0.score ?? 0) > ($1.score ?? 0) }.prefix(3))
    }
    private var glance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Heading(text: "Going well")
            glanceCard(title: "Keep doing this", symbol: "checkmark", band: .strong, items: glanceGood)
        }
    }

    private func glanceCard(title: String, symbol: String, band: Band, items: [ScoreCard.DimensionResult]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .scaledFont(12, weight: .semibold)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .foregroundStyle(Theme.color(for: band))
                .background(Theme.color(for: band).opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            ForEach(items) { d in
                VStack(alignment: .leading, spacing: 2) {
                    Text(inline(d.headline)).scaledFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(d.dimension.title) · \(d.score ?? 0)/10").scaledFont(12).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: All 10 categories

    private var categories: some View {
        VStack(alignment: .leading, spacing: 10) {
            Heading(text: "All 10 categories")
            VStack(spacing: 0) {
                ForEach(card.ordered) { d in
                    Divider()
                    CategoryRow(result: d, change: change(for: d.dimension), note: card.deductionNote(for: d.dimension),
                                deductions: card.deductionAppliedTo == d.dimension ? card.deductions ?? [] : [],
                                footer: deepDiveFooter?(d.dimension), expanded: expandAll)
                }
                Divider()
            }
        }
    }

    // MARK: What changed, and what comes after the first fix

    private func changesSection(_ baseline: CardRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Heading(text: "What changed since \(baseline.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(changes) { c in
                    Divider()
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(c.dimension.title).scaledFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                            Spacer()
                            DeltaBadge(change: c)
                        }
                        Text(c.isUnexplained ? "No new evidence, so this is most likely scoring variation." : c.reason!)
                            .scaledFont(13).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 10)
                }
                Divider()
            }
        }
    }

    private var roadmap: some View {
        VStack(alignment: .leading, spacing: 10) {
            Heading(text: "After that")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(card.roadmap, id: \.stage) { stage in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(stage.stage)")
                            .scaledFont(12, weight: .semibold)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(Theme.rule))
                            .foregroundStyle(Theme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inline(stage.change)).scaledFont(14).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                            Text(inline(stage.result)).scaledFont(13).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: About this score: the technical details, folded

    private var about: some View {
        let sc = card.scope
        return DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                Text(sc.recordDates.map { "\($0.tool): \($0.sessions) sessions, \($0.from) to \($0.to)" }.joined(separator: " · "))
                Text("\(sc.sessionsExamined) of \(record.sessionsScanned) sessions read · \(sc.tasksCheckedInDetail) tasks checked in detail")
                Text("Scored by \(record.engineLabel) (\(record.actualModel ?? record.model ?? "default model")) in \(String(format: "%.1f", sc.elapsedMinutes)) minutes")
                if card.unknownCount > 0 {
                    Text("\(card.unknownCount) categor\(card.unknownCount == 1 ? "y" : "ies") could not be scored, so the total is a range.")
                }
                ForEach(sc.limits, id: \.self) { Text("– \($0)") }
                if let notes = record.instructions { Text("Scored with your notes: \(notes)") }
                Text("Scores can move a point or two between runs. Every finding links to the sessions behind it.")
            }
            .scaledFont(13)
            .foregroundStyle(Theme.muted)
            .padding(.top, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("About this score").scaledFont(14, weight: .semibold).foregroundStyle(Theme.ink)
        }
    }
}

/// "What to fix": the card's first improvement, then each other category in the bottleneck band, weakest
/// first (the same order as the menu bar). One page at a time, moved with the arrows, the dots or the arrow keys.
struct FixCarousel: View {
    var card: ScoreCard
    @State private var page = 0
    /// The row's width, measured; the first layout uses a typical window width.
    @State private var width: CGFloat = 756
    private let spacing: CGFloat = 14

    private var others: [ScoreCard.DimensionResult] { card.nextFixes.filter { $0.isReadable } }
    private var count: Int { 1 + others.count }
    /// Each card is narrower than the row, so the next one shows at the right edge.
    private var cardWidth: CGFloat { count > 1 ? (width * 0.86).rounded() : width }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Heading(text: page == 0 ? "Fix this first" : "Also fix")
                Spacer()
                if count > 1 { navigation }
            }
            // Measures the row's width; the cards themselves are wider than it in total.
            Color.clear.frame(maxWidth: .infinity).frame(height: 0)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
            // Laid out side by side and clipped, rather than in a ScrollView, so it also renders to images.
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<count, id: \.self) { i in
                    framed(i)
                        .frame(width: cardWidth)
                        .opacity(i == page ? 1 : 0.55)
                        .onTapGesture { if i != page { withAnimation(.easeOut(duration: 0.3)) { page = i } } }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: -CGFloat(page) * (cardWidth + spacing))
            .frame(width: width, alignment: .leading)
            .clipped()
            .gesture(DragGesture(minimumDistance: 24).onEnded { drag in
                if drag.translation.width < -60 { go(1) } else if drag.translation.width > 60 { go(-1) }
            })
            if count > 1 { dots }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { go(-1); return .handled }
        .onKeyPress(.rightArrow) { go(1); return .handled }
        .onChange(of: count) { page = min(page, count - 1) }
    }

    /// One page in its box; every box in the row takes the height of the tallest.
    private func framed(_ i: Int) -> some View {
        Group {
            if i == 0 { firstPage } else if others.indices.contains(i - 1) { categoryPage(others[i - 1]) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(i == 0 ? Theme.accent : Theme.rule, lineWidth: i == 0 ? 1.5 : 1))
    }

    private func go(_ step: Int) {
        withAnimation(.easeOut(duration: 0.3)) { page = min(max(page + step, 0), count - 1) }
    }

    private var navigation: some View {
        HStack(spacing: 8) {
            Text("\(page + 1) of \(count)").scaledFont(12).monospacedDigit().foregroundStyle(Theme.muted)
            Button { go(-1) } label: { Image(systemName: "chevron.left") }
                .help("Previous")
            Button { go(1) } label: { Image(systemName: "chevron.right") }
                .help("Next")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.3)) { page = i }
                } label: {
                    Capsule()
                        .fill(i == page ? Theme.accent : Theme.rule)
                        .frame(width: i == page ? 18 : 7, height: 7)
                }
                .buttonStyle(.plain)
                .help(i == 0 ? "Fix this first" : others[i - 1].dimension.title)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func label(_ d: ScoreCard.DimensionResult?, fallback: VibemetricCore.Dimension?) -> some View {
        let title = d?.dimension.title ?? fallback?.title
        let score = d.flatMap { $0.score.map { "\($0)/10" } ?? $0.status.label }
        return Text([title?.uppercased(), score].compactMap { $0 }.joined(separator: " · "))
            .scaledFont(12, weight: .bold)
            .foregroundStyle(Theme.accent)
    }

    private var firstPage: some View {
        let imp = card.improvement
        let target = imp.dimension.flatMap { d in card.ordered.first { $0.dimension == d } }
        return VStack(alignment: .leading, spacing: 14) {
            if imp.dimension != nil { label(target, fallback: imp.dimension) }
            Text(inline(imp.title)).scaledFont(20, weight: .bold).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            LabeledRows(rows: [("What we saw", imp.situation), ("Why it matters", imp.impact ?? "")])
            if let instruction = imp.suggestedInstruction, !instruction.isEmpty {
                CopyBox(caption: "Add this to your context file or prompt", text: instruction)
            }
            if !imp.actions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(imp.actions.enumerated()), id: \.offset) { i, action in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(i + 1)").scaledFont(13, weight: .bold).foregroundStyle(Theme.accent).frame(width: 14)
                            Text(inline(action)).scaledFont(14).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            LabeledRows(rows: [("Try it on", imp.tryItOn), ("Sign it helped", imp.signOfSuccess)], muted: true)
            EvidenceChips(evidence: imp.evidence ?? [])
        }
    }

    private func categoryPage(_ d: ScoreCard.DimensionResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            label(d, fallback: nil)
            Text(inline(d.headline)).scaledFont(20, weight: .bold).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            LabeledRows(rows: [("What we saw", d.saw ?? ""), ("Why it matters", d.impact ?? ""), ("Try this", d.tryThis ?? "")],
                        boldLast: true)
            EvidenceChips(evidence: d.evidence)
        }
    }
}

/// One category: name, plain question, verdict and score; a click opens what we saw, why it matters, what to try,
/// and the evidence.
struct CategoryRow: View {
    var result: ScoreCard.DimensionResult
    var change: ScoreChange?
    var note: String?
    var deductions: [ScoreCard.Deduction] = []
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

    private var color: Color { result.band.map(Theme.color(for:)) ?? Theme.muted }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.dimension.title).scaledFont(14, weight: .semibold).foregroundStyle(Theme.ink)
                        Text(result.dimension.question).scaledFont(12).foregroundStyle(Theme.muted)
                        Text(inline(result.headline)).scaledFont(13).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 10)
                    if let change { DeltaBadge(change: change) }
                    ScorePips(score: result.score, size: 8)
                    Text(result.score.map { "\($0)/10" } ?? result.status.label)
                        .scaledFont(13, weight: .semibold)
                        .monospacedDigit()
                        .foregroundStyle(color)
                        .frame(minWidth: 40, alignment: .trailing)
                    Image(systemName: "chevron.right")
                        .scaledFont(12, weight: .semibold)
                        .foregroundStyle(Theme.muted)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Hides the details" : "Shows the details")

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    if result.isReadable {
                        LabeledRows(rows: [("What we saw", result.saw ?? ""), ("Why it matters", result.impact ?? ""),
                                           ("Try this", result.tryThis ?? "")], boldLast: true)
                    } else {
                        // A category from an older card inside a readable one: its reason as written.
                        Text(markdown(result.reason)).scaledFont(13).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    if let note {
                        Text(note).scaledFont(12, weight: .semibold).foregroundStyle(Theme.color(for: .bottleneck))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(deductions.enumerated()), id: \.offset) { _, d in
                        Text("Permission-bypass deduction (−\(d.points)): \(d.reason)")
                            .scaledFont(12).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.color(for: .bottleneck).opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    }
                    EvidenceChips(evidence: result.evidence)
                    if let footer { footer }
                }
                .padding(.leading, 2)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 12)
    }
}

/// Small grey section heading.
private struct Heading: View {
    var text: String
    var body: some View {
        Text(text.uppercased()).scaledFont(12, weight: .semibold).tracking(0.6).foregroundStyle(Theme.muted)
    }
}

/// "What we saw / Why it matters / Try this": a grey label column and the text. Empty rows are left out.
private struct LabeledRows: View {
    var rows: [(String, String)]
    var muted = false
    var boldLast = false

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
            let shown = rows.filter { !$0.1.trimmingCharacters(in: .whitespaces).isEmpty }
            ForEach(Array(shown.enumerated()), id: \.offset) { i, row in
                GridRow {
                    Text(row.0).scaledFont(13).foregroundStyle(Theme.muted).gridColumnAlignment(.leading)
                        .frame(minWidth: 110, alignment: .leading)
                    Text(inline(row.1))
                        .scaledFont(14, weight: boldLast && i == shown.count - 1 ? .semibold : .regular)
                        .foregroundStyle(muted ? Theme.muted : Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

/// Text to paste, in a box with a Copy button.
private struct CopyBox: View {
    var caption: String
    var text: String
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(caption).scaledFont(12).foregroundStyle(Theme.muted)
                Text(inline(text)).scaledFont(14).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(copied ? "Copied" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// References as "project · date" chips; a click shows what happened in that session.
private struct EvidenceChips: View {
    var evidence: [ScoreCard.Evidence]
    @State private var open: Int?

    var body: some View {
        if !evidence.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(Array(evidence.enumerated()), id: \.offset) { i, e in
                        Button {
                            open = open == i ? nil : i
                        } label: {
                            Text(e.label)
                                .scaledFont(12, weight: .medium)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .foregroundStyle(open == i ? Theme.paper : Theme.ink)
                                .background(open == i ? Theme.ink : Theme.rule.opacity(0.6), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help(e.note)
                    }
                }
                if let open, evidence.indices.contains(open) {
                    Text(inline(evidence[open].note))
                        .scaledFont(13).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.rule.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

/// Readable fields are plain text with `code` in backticks; render only that, so stray asterisks stay literal.
func inline(_ s: String) -> AttributedString {
    var result = AttributedString()
    for (i, part) in s.components(separatedBy: "`").enumerated() {
        var piece = AttributedString(part)
        if i % 2 == 1 { piece.inlinePresentationIntent = .code }
        result += piece
    }
    return result
}
