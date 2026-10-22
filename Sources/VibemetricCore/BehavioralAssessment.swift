import Foundation

/// Task observations for one non-Planning dimension, with the criteria snapshot used to judge them.
public struct BehavioralAssessment: Codable, Sendable {
    public typealias Level = PlanningAssessment.Level
    public typealias Source = PlanningAssessment.Source
    public typealias Criteria = PlanningAssessment.Criteria
    public typealias TaskObservation = PlanningAssessment.TaskObservation
    public typealias Explanation = PlanningAssessment.Explanation

    public struct Competency: Codable, Sendable, Identifiable {
        public var id: String
        public var title: String
        public var summary: String
        public var whyItHelps: String
        public var sources: [Source]
        public var criteria: Criteria
        public var tasks: [TaskObservation]
        public var solution: String?
        public var explanation: Explanation?

        public init(id: String, title: String, summary: String, sources: [Source], criteria: Criteria,
                    tasks: [TaskObservation], solution: String? = nil, whyItHelps: String = "",
                    explanation: Explanation? = nil) {
            self.id = id
            self.title = title
            self.summary = summary
            self.whyItHelps = whyItHelps
            self.sources = sources
            self.criteria = criteria
            self.tasks = tasks
            self.solution = solution
            self.explanation = explanation
        }

        enum CodingKeys: String, CodingKey {
            case id, title, summary, whyItHelps, sources, criteria, tasks, solution, explanation
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
            summary = try container.decode(String.self, forKey: .summary)
            whyItHelps = try container.decodeIfPresent(String.self, forKey: .whyItHelps) ?? ""
            sources = try container.decodeIfPresent([Source].self, forKey: .sources) ?? []
            criteria = try container.decodeIfPresent(Criteria.self, forKey: .criteria)
                ?? .init(high: "", medium: "", low: "")
            tasks = try container.decode([TaskObservation].self, forKey: .tasks)
            solution = try container.decodeIfPresent(String.self, forKey: .solution)
            explanation = try container.decodeIfPresent(Explanation.self, forKey: .explanation)
        }

        public var highCount: Int { tasks.filter { $0.level == .high }.count }
        public var mediumCount: Int { tasks.filter { $0.level == .medium }.count }
        public var lowCount: Int { tasks.filter { $0.level == .low }.count }
        public var unknownCount: Int { tasks.filter { $0.level == .unknown }.count }
        public var notApplicableCount: Int { tasks.filter { $0.level == .notApplicable }.count }
        public var assessedCount: Int { highCount + mediumCount + lowCount }

        public var level: Level {
            guard assessedCount > 0 else {
                return !tasks.isEmpty && notApplicableCount == tasks.count ? .notApplicable : .unknown
            }
            if highCount * 5 >= assessedCount * 4 { return .high }
            if lowCount * 2 >= assessedCount { return .low }
            return .medium
        }
    }

    public enum ValidationError: Error, LocalizedError {
        case invalidCompetencies
        case duplicateTaskID(String, String)
        case missingTaskEvidence(String, String)

        public var errorDescription: String? {
            switch self {
            case .invalidCompetencies:
                "The assessment must contain each competency defined for its dimension exactly once."
            case let .duplicateTaskID(id, taskID):
                "Competency \(id) repeats task \(taskID)."
            case let .missingTaskEvidence(id, taskID):
                "Competency \(id) has no evidence for assessed task \(taskID)."
            }
        }
    }

    public var competencies: [Competency]

    public init(competencies: [Competency]) {
        self.competencies = competencies
    }

    public func validate(expectedIDs: [String]) throws {
        guard !expectedIDs.isEmpty, Set(expectedIDs).count == expectedIDs.count,
              competencies.count == expectedIDs.count,
              Set(competencies.map(\.id)) == Set(expectedIDs) else {
            throw ValidationError.invalidCompetencies
        }
        for competency in competencies {
            var seen = Set<String>()
            for task in competency.tasks {
                guard seen.insert(task.taskID).inserted else {
                    throw ValidationError.duplicateTaskID(competency.id, task.taskID)
                }
                if [.high, .medium, .low].contains(task.level), task.evidence.isEmpty {
                    throw ValidationError.missingTaskEvidence(competency.id, task.taskID)
                }
            }
        }
    }

    public func ordered(expectedIDs: [String]) -> [Competency] {
        expectedIDs.compactMap { id in competencies.first { $0.id == id } }
    }

    public var score: Int? {
        let applicable = competencies.filter { $0.level != .notApplicable }
        guard !applicable.isEmpty else { return nil }
        let weighted = applicable.reduce(0) { $0 + $1.level.scoreUnits }
        let denominator = 3 * applicable.count
        return (20 * weighted + denominator) / (2 * denominator)
    }

    public func calculatedAudit(dimension: Dimension, expectedIDs: [String]) -> String {
        let applicable = competencies.filter { $0.level != .notApplicable }
        let weighted = applicable.reduce(0) { $0 + $1.level.scoreUnits }
        let counts = ordered(expectedIDs: expectedIDs).map {
            "\($0.id)=\($0.level.rawValue) (H=\($0.highCount), M=\($0.mediumCount), L=\($0.lowCount), U=\($0.unknownCount), NA=\($0.notApplicableCount))"
        }.joined(separator: "; ")
        let arithmetic = applicable.isEmpty
            ? "n=0; raw=not_assessable; rounded=null"
            : "n=\(applicable.count); raw=\(10 * weighted)/\(3 * applicable.count); rounded=\(score!)"
        return "\(dimension.rawValue) calculated audit: \(counts); \(arithmetic)."
    }

    public func markdown(language: String, expectedIDs: [String]) -> String {
        let korean = language.lowercased().hasPrefix("ko")
        return ordered(expectedIDs: expectedIDs).map { competency in
            let level = competency.level.label(language: language)
            var parts = ["### \(competency.title) · \(level)", competency.summary]
            let counts = korean
                ? "관찰한 과제 중 상 \(competency.highCount), 중 \(competency.mediumCount), 하 \(competency.lowCount)입니다. 미확인 \(competency.unknownCount), 해당 없음 \(competency.notApplicableCount)은 이 비율에서 제외합니다."
                : "Among observed tasks, \(competency.highCount) are high, \(competency.mediumCount) medium, and \(competency.lowCount) low. The \(competency.unknownCount) unknown and \(competency.notApplicableCount) not-applicable cases are outside that proportion."
            let policy = korean
                ? "판정 가능한 과제 중 상이 80% 이상이면 상, 하가 50% 이상이면 하, 나머지는 중입니다. 이 수치 경계는 제품 정책입니다."
                : "The aggregate is high when at least 80% of assessable tasks are high, low when at least 50% are low, and medium otherwise. These numerical thresholds are product policy."
            let explanation = competency.explanation ?? Explanation(
                sourceBasis: competency.sources.map(\.note).joined(separator: " "),
                criteria: "\(Level.high.label(language: language)): \(competency.criteria.high) \(Level.medium.label(language: language)): \(competency.criteria.medium) \(Level.low.label(language: language)): \(competency.criteria.low)",
                observedBehavior: competency.tasks.map { task in
                    let references = task.evidence.map { "\($0.label) · \($0.sessionId): \($0.note)" }.joined(separator: "; ")
                    return "\(task.project) · \(task.taskID): \(task.observation) \(task.rationale) \(references)"
                }.joined(separator: "\n\n"),
                overallJudgment: counts + " " + policy)
            parts.append(explanation.markdown(language: language, sources: competency.sources))
            if [.medium, .low].contains(competency.level),
               let solution = competency.solution, !solution.isEmpty {
                parts.append((korean ? "**해결 방법**\n" : "**Solution**\n") + solution)
            }
            return parts.joined(separator: "\n\n")
        }.joined(separator: "\n\n")
    }
}
