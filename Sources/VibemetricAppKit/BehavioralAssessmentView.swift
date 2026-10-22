import SwiftUI
import VibemetricCore

struct BehavioralAssessmentView: View {
    var assessment: BehavioralAssessment
    var expandAll: Bool

    private var strengths: [BehavioralAssessment.Competency] {
        assessment.competencies.filter { $0.level == .high }
    }

    private var problems: [BehavioralAssessment.Competency] {
        assessment.competencies.filter { $0.level == .medium || $0.level == .low }
    }

    private var unassessed: [BehavioralAssessment.Competency] {
        assessment.competencies.filter { $0.level == .unknown || $0.level == .notApplicable }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !strengths.isEmpty {
                section("What's working", symbol: "checkmark.circle.fill",
                        color: Theme.color(for: .strong), items: strengths)
            }
            if !problems.isEmpty {
                section("Problem", symbol: "exclamationmark.triangle.fill",
                        color: Theme.color(for: .bottleneck), items: problems)
            }
            if !unassessed.isEmpty {
                section("Not rated", symbol: "info.circle", color: Theme.muted, items: unassessed)
            }
            if problems.contains(where: { !($0.solution ?? "").isEmpty }) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Solution", systemImage: "lightbulb.fill")
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(Theme.color(for: .strong))
                    ForEach(problems, id: \.id) { competency in
                        if let solution = competency.solution, !solution.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(competency.title).scaledFont(16, weight: .semibold)
                                Text(inline(solution)).scaledFont(15)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                            }
                            .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .modifier(BehavioralPanel(color: Theme.color(for: .strong)))
            }
        }
    }

    private func section(_ title: String, symbol: String, color: Color,
                         items: [BehavioralAssessment.Competency]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .scaledFont(15, weight: .bold)
                .foregroundStyle(color)
            ForEach(items, id: \.id) { competency in
                BehavioralCompetencyView(competency: competency, expandAll: expandAll)
            }
        }
        .modifier(BehavioralPanel(color: color))
    }
}

private struct BehavioralCompetencyView: View {
    var competency: BehavioralAssessment.Competency
    var expandAll: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: Bool

    init(competency: BehavioralAssessment.Competency, expandAll: Bool) {
        self.competency = competency
        self.expandAll = expandAll
        _expanded = State(initialValue: expandAll)
    }

    private var levelLabel: String {
        competency.level.label(language: "en")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .smooth) { expanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(competency.title).scaledFont(16, weight: .semibold)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(levelLabel)
                            .scaledFont(13, weight: .semibold)
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: true, vertical: false)
                        Image(systemName: "chevron.right")
                            .scaledFont(12, weight: .semibold)
                            .foregroundStyle(Theme.muted)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    Text(inline(competency.summary))
                        .scaledFont(15)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(competency.summary)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(competency.title), \(levelLabel)")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityHint(expanded ? "Hides the assessment" : "Shows the assessment")
            .accessibilityIdentifier("behavioral.criteria.\(competency.id)")

            if expanded { details }
        }
        .onChange(of: expandAll) { _, value in expanded = value }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            explanationPart("Why we look for this", text: competency.explanation?.sourceBasis
                            ?? competency.sources.map(\.note).joined(separator: " "))
            if !competency.sources.isEmpty {
                ForEach(Array(competency.sources.enumerated()), id: \.offset) { _, source in
                    if let url = URL(string: source.url), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                        Link(source.title, destination: url)
                            .scaledFont(13, weight: .medium)
                            .foregroundStyle(Theme.muted)
                            .help(source.note)
                    }
                }
            }
            explanationPart("How we rate this", text: competency.explanation?.criteria ?? fallbackCriteria)
            explanationPart("What you did", text: competency.explanation?.observedBehavior ?? fallbackObservations)
            explanationPart("Why you got this rating", text: competency.explanation?.overallJudgment ?? fallbackJudgment)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func explanationPart(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).scaledFont(14, weight: .semibold).foregroundStyle(Theme.ink)
            Text(inline(text)).scaledFont(14).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fallbackCriteria: String {
        "High: \(competency.criteria.high) Medium: \(competency.criteria.medium) Low: \(competency.criteria.low)"
    }

    private var fallbackObservations: String {
        let examples = competency.tasks.prefix(3).map {
            "\($0.project): \($0.observation) \($0.rationale)"
        }
        return examples.isEmpty ? "This result has no examples to rate." : examples.joined(separator: " ")
    }

    private var fallbackJudgment: String {
        let counts = "High \(competency.highCount), Medium \(competency.mediumCount), Low \(competency.lowCount), Unknown \(competency.unknownCount), Not applicable \(competency.notApplicableCount)."
        return "Your rating is \(competency.level.label(language: "en")). \(counts) High means at least 80% of rated tasks were High. Low means at least half were Low. Other rated combinations are Medium. This uses all rated tasks, including those not shown above."
    }

}

private struct BehavioralPanel: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}
