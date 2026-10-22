import SwiftUI
import VibemetricCore

struct PlanningAssessmentView: View {
    var assessment: PlanningAssessment
    var expandAll: Bool

    private var strengths: [PlanningAssessment.Competency] {
        assessment.ordered.filter { $0.level == .high }
    }
    private var problems: [PlanningAssessment.Competency] {
        assessment.ordered.filter { $0.level == .medium || $0.level == .low }
    }
    private var unassessed: [PlanningAssessment.Competency] {
        assessment.ordered.filter { $0.level == .unknown || $0.level == .notApplicable }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !strengths.isEmpty {
                section("What's working", symbol: "checkmark.circle.fill", color: Theme.color(for: .strong), items: strengths)
            }
            if !problems.isEmpty {
                section("Problem", symbol: "exclamationmark.triangle.fill", color: Theme.color(for: .bottleneck), items: problems)
            }
            if !unassessed.isEmpty {
                section("Not rated", symbol: "info.circle", color: Theme.muted, items: unassessed)
            }
            if problems.contains(where: { !($0.solution ?? "").isEmpty }) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Solution", systemImage: "lightbulb.fill")
                        .scaledFont(15, weight: .bold)
                        .foregroundStyle(Theme.color(for: .strong))
                    ForEach(problems, id: \.id.rawValue) { competency in
                        if let solution = competency.solution, !solution.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(competency.id.title)
                                    .scaledFont(16, weight: .semibold)
                                Text(inline(solution)).scaledFont(15)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(Theme.ink)
                        }
                    }
                }
                .modifier(PlanningPanel(color: Theme.color(for: .strong)))
            }
        }
    }

    private func section(_ title: String, symbol: String, color: Color,
                         items: [PlanningAssessment.Competency]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .scaledFont(15, weight: .bold)
                .foregroundStyle(color)
            ForEach(items, id: \.id.rawValue) { competency in
                PlanningCompetencyView(competency: competency, expandAll: expandAll)
            }
        }
        .modifier(PlanningPanel(color: color))
    }
}

private struct PlanningCompetencyView: View {
    var competency: PlanningAssessment.Competency
    var expandAll: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded: Bool

    init(competency: PlanningAssessment.Competency, expandAll: Bool) {
        self.competency = competency
        self.expandAll = expandAll
        _expanded = State(initialValue: expandAll)
    }

    private var title: String { competency.id.title }
    private var levelLabel: String { competency.level.label(language: "en") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .smooth) {
                    expanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title).scaledFont(16, weight: .semibold)
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
                        .fixedSize(horizontal: false, vertical: true)
                        .help(competency.summary)
                }
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(levelLabel)")
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityHint(expanded ? "Hides the assessment details" : "Shows the assessment details")
            .accessibilityIdentifier("planning.criteria.\(competency.id.rawValue)")
            if expanded { details }
        }
        .onChange(of: expandAll) { _, value in expanded = value }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailSection("Why we look for this") {
                detailText(competency.explanation?.sourceBasis ?? competency.sources.map(\.note).joined(separator: " "))
                ForEach(Array(competency.sources.enumerated()), id: \.offset) { _, source in
                    if let url = URL(string: source.url), url.scheme?.lowercased() == "https" {
                        Link(source.title, destination: url)
                            .scaledFont(13, weight: .medium)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            detailSection("How we rate this") {
                detailText(competency.explanation?.criteria ?? "High. \(competency.criteria.high)\nMedium. \(competency.criteria.medium)\nLow. \(competency.criteria.low)")
            }
            detailSection("What you did") {
                if let explanation = competency.explanation {
                    detailText(explanation.observedBehavior)
                } else if representativeTasks.isEmpty {
                    detailText("This result has no examples to rate.")
                } else {
                    ForEach(representativeTasks, id: \.taskID) { task in
                        detailText("\(task.observation) \(task.rationale)")
                    }
                }
            }
            detailSection("Why you got this rating") {
                if let explanation = competency.explanation {
                    detailText(explanation.overallJudgment)
                } else {
                    detailText("High \(competency.highCount), Medium \(competency.mediumCount), Low \(competency.lowCount). Your rating is \(levelLabel).")
                    detailText("This older result has no written explanation for the rating.")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private var representativeTasks: [PlanningAssessment.TaskObservation] {
        let assessed = competency.tasks.filter { [.high, .medium, .low].contains($0.level) }
        guard let first = assessed.first else { return [] }
        if let contrasting = assessed.first(where: { $0.level != first.level }) {
            return [first, contrasting]
        }
        return [first]
    }

    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).scaledFont(14, weight: .semibold).foregroundStyle(Theme.ink)
            content()
        }
    }

    private func detailText(_ text: String) -> some View {
        Text(inline(text)).scaledFont(14).foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct PlanningPanel: ViewModifier {
    var color: Color

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}
