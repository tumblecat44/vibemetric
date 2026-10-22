import Foundation
import Testing
@testable import VibemetricCore

struct BehavioralAssessmentTests {
    private typealias Level = BehavioralAssessment.Level
    private typealias Competency = BehavioralAssessment.Competency

    private func competency(_ id: String = "example", levels: [Level]) -> Competency {
        Competency(id: id, title: "Saved title", summary: "Cedar checks the requested behavior.",
                   sources: [.init(title: "Saved source", url: "https://example.org/saved", note: "Saved note")],
                   criteria: .init(high: "Saved high", medium: "Saved medium", low: "Saved low"),
                   tasks: levels.enumerated().map { index, level in
                       .init(taskID: "task-\(index)", project: "Cedar", level: level,
                             observation: "A behavior check was requested.", rationale: "The check addresses the task.",
                             evidence: [.init(tool: "codex", sessionId: "fictional-session", date: "2026-10-22",
                                              note: "Behavior check", project: "Cedar")])
                   }, solution: "Check the requested behavior in the next task.", whyItHelps: "Saved explanation")
    }

    private func assessment(_ guide: RubricGuide.DimensionGuide, levels: [Level]) -> BehavioralAssessment {
        .init(competencies: guide.competencies.enumerated().map { index, definition in
            competency(definition.id, levels: [levels[index % levels.count]])
        })
    }

    private func card() throws -> ScoreCard {
        try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
    }

    private func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    @Test func legacyCardsRemainUnchangedAndSavedSnapshotsRoundTrip() throws {
        var result = try card()
        #expect(result.dimensions.allSatisfy { $0.assessment == nil })
        let before = try encoded(result)
        try result.normalizeBehavioralAssessments()
        #expect(try encoded(result) == before)
        result.dimensions[1].assessment = .init(competencies: [competency(levels: [.medium])])
        let decoded = try JSONDecoder().decode(ScoreCard.self, from: encoded(result))
        let saved = try #require(decoded.dimensions[1].assessment?.competencies.first)
        #expect(saved.title == "Saved title")
        #expect(saved.sources.first?.url == "https://example.org/saved")
        #expect(saved.criteria.high == "Saved high")
        #expect(saved.whyItHelps == "Saved explanation")
        #expect(saved.tasks.first?.evidence.first?.sessionId == "fictional-session")
    }

    @Test func liveResponseCanOmitCanonicalSnapshotFields() throws {
        let json = #"{"competencies":[{"id":"example","summary":"A behavior was checked.","tasks":[],"solution":null}]}"#
        let decoded = try JSONDecoder().decode(BehavioralAssessment.self, from: Data(json.utf8))
        let value = try #require(decoded.competencies.first)
        #expect(value.title.isEmpty)
        #expect(value.sources.isEmpty)
        #expect(value.criteria.high.isEmpty)
        #expect(value.whyItHelps.isEmpty)
        #expect(value.explanation == nil)
    }

    @Test func explanationSurvivesCanonicalNormalizationAndRoundTrip() throws {
        let guide = try #require(RubricGuide.load().guide(for: .contextEngineering))
        var result = try card()
        result.dimensions[1].assessment = assessment(guide, levels: [.medium])
        result.dimensions[1].assessment?.competencies[0].explanation = .init(
            sourceBasis: "The supplied guide recommends usable project knowledge.",
            criteria: "High applies the needed facts; medium leaves a relevant gap; low ignores an established need.",
            observedBehavior: "Cedar's task used a project instruction.",
            overallJudgment: "One assessed task establishes medium behavior.")
        try result.normalizeBehavioralAssessments()
        let decoded = try JSONDecoder().decode(ScoreCard.self, from: encoded(result))
        let explanation = try #require(decoded.dimensions[1].assessment?.competencies[0].explanation)
        #expect(explanation.sourceBasis == "The supplied guide recommends usable project knowledge.")
        #expect(explanation.criteria.contains("medium leaves a relevant gap"))
        #expect(explanation.observedBehavior == "Cedar's task used a project instruction.")
        #expect(explanation.overallJudgment == "One assessed task establishes medium behavior.")
        #expect(decoded.dimensions[1].reason.contains(explanation.overallJudgment))
    }

    @Test func thresholdBoundariesIgnoreUnknownAndNotApplicableTasks() {
        #expect(competency(levels: [.high, .high, .high, .high, .medium]).level == .high)
        #expect(competency(levels: [.high, .high, .high, .medium, .medium]).level == .medium)
        #expect(competency(levels: [.low, .low, .medium, .high]).level == .low)
        #expect(competency(levels: [.low, .low, .medium, .medium, .high]).level == .medium)
        let value = competency(levels: [.high, .high, .high, .high, .medium, .unknown, .notApplicable])
        #expect(value.level == .high)
        #expect(value.assessedCount == 5)
        #expect(value.unknownCount == 1)
        #expect(value.notApplicableCount == 1)
        #expect(competency(levels: [.unknown, .notApplicable]).level == .unknown)
        #expect(competency(levels: []).level == .unknown)
    }

    @Test func equalWeightArithmeticExcludesOnlyNotApplicableAndRoundsHalfUp() {
        func assessment(_ levels: [Level]) -> BehavioralAssessment {
            .init(competencies: levels.enumerated().map { competency("c-\($0.offset)", levels: [$0.element]) })
        }
        #expect(assessment([.high, .high, .unknown, .notApplicable]).score == 7)
        #expect(assessment([.unknown, .unknown]).score == 0)
        #expect(assessment([.notApplicable, .notApplicable]).score == nil)
        #expect(assessment([.high, .medium, .high, .low]).score == 8)
        #expect(assessment([.high, .medium, .low, .unknown, .notApplicable]).score == 5)
    }

    @Test func exactCompetencyIDsAndIndependentTasksAreRequired() throws {
        var result = BehavioralAssessment(competencies: [competency("one", levels: [.high]),
                                                        competency("two", levels: [.medium])])
        try result.validate(expectedIDs: ["one", "two"])
        result.competencies[1].id = "one"
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.validate(expectedIDs: ["one", "two"]) }
        result.competencies[1].id = "other-dimension-id"
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.validate(expectedIDs: ["one", "two"]) }
        result.competencies[1].id = "two"
        result.competencies[0].tasks.append(result.competencies[0].tasks[0])
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.validate(expectedIDs: ["one", "two"]) }
        result.competencies.removeLast()
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.validate(expectedIDs: ["one", "two"]) }
    }

    @Test func allObservedTasksAreAcceptedAndAssessedTasksStillRequireEvidence() throws {
        var result = BehavioralAssessment(competencies: [competency(levels: [.high, .medium, .low, .high, .medium,
                                                                            .unknown, .notApplicable])])
        result.competencies[0].tasks[5].evidence = []
        result.competencies[0].tasks[6].evidence = []
        try result.validate(expectedIDs: ["example"])
        result.competencies[0].tasks[5].level = .medium
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.validate(expectedIDs: ["example"]) }
        result.competencies[0].tasks[5].evidence = result.competencies[0].tasks[0].evidence
        try result.validate(expectedIDs: ["example"])
        #expect(result.competencies[0].assessedCount == 6)
        result.competencies[0].tasks[5].level = .unknown
        result.competencies[0].tasks[0].evidence = []
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.validate(expectedIDs: ["example"]) }
    }

    @Test func everyDimensionUsesItsCatalogCountAndCanonicalSnapshot() throws {
        let catalog = try RubricGuide.load()
        #expect(catalog.dimensions.count == 9)
        for guide in catalog.dimensions {
            var result = try card()
            let index = try #require(result.dimensions.firstIndex { $0.dimension == guide.dimension })
            let preserved = try encoded(result.dimensions.filter { $0.dimension != guide.dimension })
            result.dimensions[index].assessment = assessment(guide, levels: [.high, .medium, .low, .unknown])
            try result.normalizeBehavioralAssessments()
            let normalized = try #require(result.dimensions[index].assessment)
            #expect(normalized.competencies.count == guide.competencies.count)
            #expect(normalized.competencies.map(\.id) == guide.competencies.map(\.id))
            for (snapshot, definition) in zip(normalized.competencies, guide.competencies) {
                #expect(snapshot.title == definition.title)
                #expect(snapshot.criteria.high == definition.high)
                #expect(snapshot.sources.map(\.url) == definition.sources.map(\.url))
                #expect(snapshot.whyItHelps == definition.whyItHelps)
            }
            #expect(result.dimensions[index].score == normalized.score)
            #expect(result.dimensions[index].status == .scored)
            #expect(try encoded(result.dimensions.filter { $0.dimension != guide.dimension }) == preserved)
            let first = try encoded(result)
            try result.normalizeBehavioralAssessments()
            #expect(try encoded(result) == first)
            #expect(result.scope.limits.filter { $0.hasPrefix("\(guide.dimension.rawValue) calculated audit:") }.count == 1)
        }
    }

    @Test func allUnknownAndAllNotApplicableHaveDifferentStatuses() throws {
        let guide = try #require(RubricGuide.load().guide(for: .contextEngineering))
        var result = try card()
        result.dimensions[1].assessment = assessment(guide, levels: [.unknown])
        try result.normalizeBehavioralAssessments()
        #expect(result.dimensions[1].score == 0)
        #expect(result.dimensions[1].status == .scored)
        #expect(result.dimensions[1].strengths == [])
        #expect(result.dimensions[1].saw == "")
        #expect(result.dimensions[1].solutionSteps == [])
        result.dimensions[1].assessment = assessment(guide, levels: [.notApplicable])
        try result.normalizeBehavioralAssessments()
        #expect(result.dimensions[1].score == nil)
        #expect(result.dimensions[1].status == .notAssessable)
    }

    @Test func invalidLaterDimensionCannotPartlyNormalizeEarlierDimension() throws {
        let catalog = try RubricGuide.load()
        let first = try #require(catalog.guide(for: .contextEngineering))
        let later = try #require(catalog.guide(for: .efficiencyCost))
        var result = try card()
        result.dimensions[1].assessment = assessment(first, levels: [.high])
        result.dimensions[9].assessment = assessment(later, levels: [.low])
        result.dimensions[9].assessment?.competencies[0].id = "wrong-id"
        let before = try encoded(result)
        #expect(throws: BehavioralAssessment.ValidationError.self) { try result.normalizeBehavioralAssessments() }
        #expect(try encoded(result) == before)
    }

    @Test func narrativeAndSolutionsFollowObservedCompetencyLevels() throws {
        let guide = try #require(RubricGuide.load().guide(for: .contextEngineering))
        var result = try card()
        result.language = "ko"
        result.dimensions[1].score = 10
        result.dimensions[1].headline = "All competencies are high."
        result.dimensions[1].impact = "No gaps remain."
        result.dimensions[1].changeReason = "Everything improved."
        result.dimensions[1].assessment = assessment(guide, levels: [.high, .medium, .low, .unknown])
        try result.normalizeBehavioralAssessments()
        let value = result.dimensions[1]
        let competencies = try #require(value.assessment?.competencies)
        let gaps = competencies.filter { $0.level == .medium || $0.level == .low }
        #expect(value.strengths == competencies.filter { $0.level == .high }.map(\.summary))
        #expect(value.saw == gaps.map(\.summary).joined(separator: "\n\n"))
        #expect(value.solutionSteps == gaps.compactMap(\.solution))
        #expect(value.headline != "All competencies are high.")
        #expect(value.impact == nil)
        #expect(value.changeReason == nil)
        #expect(value.reason.contains("fictional-session"))
        #expect(value.reason.contains("**출처 근거**"))
    }

    @Test func structuredOutputBranchesMatchEachCatalogDefinition() throws {
        let catalog = try RubricGuide.load()
        let schema = try #require(JSONSerialization.jsonObject(with: Data(JSONSchema.scoreCard.utf8)) as? [String: Any])
        let root = try #require(schema["properties"] as? [String: Any])
        let dimensions = try #require(root["dimensions"] as? [String: Any])
        let items = try #require(dimensions["items"] as? [String: Any])
        let branches = try #require(items["anyOf"] as? [[String: Any]])
        #expect(branches.count == 10)
        for branch in branches {
            let fields = try #require(branch["properties"] as? [String: Any])
            let dimension = try #require(fields["dimension"] as? [String: Any])
            let id = try #require((dimension["enum"] as? [String])?.first)
            let assessment = try #require(fields["assessment"] as? [String: Any])
            let detail = try #require(fields[id == Dimension.planningSpecs.rawValue ? "planning" : "assessment"] as? [String: Any])
            let detailFields = try #require(detail["properties"] as? [String: Any])
            let entries = try #require(detailFields["competencies"] as? [String: Any])
            let entry = try #require(entries["items"] as? [String: Any])
            #expect((entry["required"] as? [String])?.contains("explanation") == true)
            let entryFields = try #require(entry["properties"] as? [String: Any])
            let explanation = try #require(entryFields["explanation"] as? [String: Any])
            #expect(explanation["type"] as? String == "object")
            #expect(Set(try #require(explanation["required"] as? [String])) == Set(["sourceBasis", "criteria", "observedBehavior", "overallJudgment"]))
            if id == Dimension.planningSpecs.rawValue {
                #expect(assessment["type"] as? String == "null")
                continue
            }
            let guide = try #require(catalog.dimensions.first { $0.dimension.rawValue == id })
            let assessmentFields = try #require(assessment["properties"] as? [String: Any])
            let competencies = try #require(assessmentFields["competencies"] as? [String: Any])
            #expect(competencies["minItems"] as? Int == guide.competencies.count)
            #expect(competencies["maxItems"] as? Int == guide.competencies.count)
            let competency = try #require(competencies["items"] as? [String: Any])
            #expect(Set(try #require(competency["required"] as? [String])) == Set(["id", "summary", "tasks", "explanation", "solution"]))
            let competencyFields = try #require(competency["properties"] as? [String: Any])
            let ids = try #require(competencyFields["id"] as? [String: Any])
            #expect(ids["enum"] as? [String] == guide.competencies.map(\.id))
            #expect((fields["planning"] as? [String: Any])?["type"] as? String == "null")
        }
    }
}
