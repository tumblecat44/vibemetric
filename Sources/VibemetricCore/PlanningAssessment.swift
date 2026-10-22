import Foundation

public struct PlanningAssessment: Codable, Sendable {
    public enum CompetencyID: String, Codable, CaseIterable, Sendable {
        case outcomesCompletion = "outcomes_completion"
        case constraints
        case taskContext = "task_context"
        case ambiguityResolution = "ambiguity_resolution"

        public var title: String {
            switch self {
            case .outcomesCompletion: "End-user outcomes and completion criteria"
            case .constraints: "Constraints"
            case .taskContext: "Task context"
            case .ambiguityResolution: "Clarifying ambiguous requirements"
            }
        }

        public func title(language: String) -> String {
            guard language.lowercased().hasPrefix("ko") else { return title }
            switch self {
            case .outcomesCompletion: return "최종 사용자 결과와 완료 기준"
            case .constraints: return "제약 조건"
            case .taskContext: return "작업 맥락"
            case .ambiguityResolution: return "모호한 요구사항 명확화"
            }
        }
    }

    public enum Level: String, Codable, CaseIterable, Sendable {
        case high, medium, low, unknown
        case notApplicable = "not_applicable"

        var scoreUnits: Int {
            switch self {
            case .high: 3
            case .medium: 2
            case .low: 1
            case .unknown, .notApplicable: 0
            }
        }

        public func label(language: String) -> String {
            let korean = language.lowercased().hasPrefix("ko")
            switch self {
            case .high: return korean ? "상" : "High"
            case .medium: return korean ? "중" : "Medium"
            case .low: return korean ? "하" : "Low"
            case .unknown: return korean ? "미확인" : "Unknown"
            case .notApplicable: return korean ? "해당 없음" : "Not applicable"
            }
        }
    }

    public struct Source: Codable, Sendable {
        public var title: String
        public var url: String
        public var note: String

        public init(title: String, url: String, note: String) {
            self.title = title
            self.url = url
            self.note = note
        }
    }

    public struct Criteria: Codable, Sendable {
        public var high: String
        public var medium: String
        public var low: String

        public init(high: String, medium: String, low: String) {
            self.high = high
            self.medium = medium
            self.low = low
        }
    }

    public struct Explanation: Codable, Sendable {
        public var sourceBasis: String
        public var criteria: String
        public var observedBehavior: String
        public var overallJudgment: String

        public init(sourceBasis: String, criteria: String, observedBehavior: String, overallJudgment: String) {
            self.sourceBasis = sourceBasis
            self.criteria = criteria
            self.observedBehavior = observedBehavior
            self.overallJudgment = overallJudgment
        }

        func markdown(language: String, sources: [Source]) -> String {
            let korean = language.lowercased().hasPrefix("ko")
            var parts = [(korean ? "**출처 근거**\n" : "**Source basis**\n") + sourceBasis]
            parts += sources.map { "- [\($0.title)](\($0.url))" }
            parts.append((korean ? "**판정 기준**\n" : "**Criteria**\n") + criteria)
            parts.append((korean ? "**관찰한 행동**\n" : "**Observed behavior**\n") + observedBehavior)
            parts.append((korean ? "**종합 판단**\n" : "**Overall judgment**\n") + overallJudgment)
            return parts.joined(separator: "\n\n")
        }
    }

    public struct TaskObservation: Codable, Sendable {
        public var taskID: String
        public var project: String
        public var level: Level
        public var observation: String
        public var rationale: String
        public var evidence: [ScoreCard.Evidence]

        public init(taskID: String, project: String, level: Level, observation: String,
                    rationale: String, evidence: [ScoreCard.Evidence]) {
            self.taskID = taskID
            self.project = project
            self.level = level
            self.observation = observation
            self.rationale = rationale
            self.evidence = evidence
        }
    }

    public struct Competency: Codable, Sendable, Identifiable {
        public var id: CompetencyID
        public var summary: String
        public var sources: [Source]
        public var criteria: Criteria
        public var tasks: [TaskObservation]
        public var solution: String?
        public var explanation: Explanation?

        public init(id: CompetencyID, summary: String, sources: [Source], criteria: Criteria,
                    tasks: [TaskObservation], solution: String? = nil, explanation: Explanation? = nil) {
            self.id = id
            self.summary = summary
            self.sources = sources
            self.criteria = criteria
            self.tasks = tasks
            self.solution = solution
            self.explanation = explanation
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
        case duplicateTaskID(CompetencyID, String)
        case missingTaskEvidence(CompetencyID, String)
        case unsupportedSourceURL(CompetencyID, String)

        public var errorDescription: String? {
            switch self {
            case .invalidCompetencies:
                return "Planning must contain each of its four competencies exactly once."
            case let .duplicateTaskID(id, taskID):
                return "Planning competency \(id.rawValue) repeats task \(taskID)."
            case let .missingTaskEvidence(id, taskID):
                return "Planning competency \(id.rawValue) has no evidence for assessed task \(taskID)."
            case let .unsupportedSourceURL(id, url):
                return "Planning competency \(id.rawValue) uses an unsupported source URL: \(url)."
            }
        }
    }

    public var competencies: [Competency]

    public init(competencies: [Competency]) {
        self.competencies = competencies
    }

    private static let sourceURLs: Set<String> = [
        "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/principle-prove-it-works/SKILL.md",
        "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/sharpen/SKILL.md",
        "https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md",
        "https://code.claude.com/docs/en/best-practices",
        "https://raw.githubusercontent.com/github/spec-kit/main/templates/spec-template.md"
    ]

    public func validate() throws {
        guard competencies.count == CompetencyID.allCases.count,
              Set(competencies.map(\.id)) == Set(CompetencyID.allCases) else {
            throw ValidationError.invalidCompetencies
        }
        for competency in competencies {
            for source in competency.sources where !Self.sourceURLs.contains(source.url) {
                throw ValidationError.unsupportedSourceURL(competency.id, source.url)
            }
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

    public var ordered: [Competency] {
        CompetencyID.allCases.compactMap { id in competencies.first { $0.id == id } }
    }

    public var score: Int? {
        let applicable = competencies.filter { $0.level != .notApplicable }
        guard !applicable.isEmpty else { return nil }
        let weighted = applicable.reduce(0) { $0 + $1.level.scoreUnits }
        let denominator = 3 * applicable.count
        return (20 * weighted + denominator) / (2 * denominator)
    }

    public var calculatedAudit: String {
        let applicable = competencies.filter { $0.level != .notApplicable }
        let weighted = applicable.reduce(0) { $0 + $1.level.scoreUnits }
        let counts = ordered.map {
            "\($0.id.rawValue)=\($0.level.rawValue) (H=\($0.highCount), M=\($0.mediumCount), L=\($0.lowCount), U=\($0.unknownCount), NA=\($0.notApplicableCount))"
        }.joined(separator: "; ")
        let arithmetic = applicable.isEmpty
            ? "n=0; raw=not_assessable; rounded=null"
            : "n=\(applicable.count); raw=\(10 * weighted)/\(3 * applicable.count); rounded=\(score!)"
        return "Planning & Specs calculated audit: \(counts); \(arithmetic)."
    }

    public func markdown(language: String) -> String {
        let korean = language.lowercased().hasPrefix("ko")
        return ordered.map { competency in
            let title = competency.id.title(language: language)
            let level = competency.level.label(language: language)
            var parts = ["### \(title) · \(level)", competency.summary]
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
