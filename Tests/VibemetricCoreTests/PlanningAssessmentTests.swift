import Foundation
import Testing
@testable import VibemetricCore

struct PlanningAssessmentTests {
    private typealias Level = PlanningAssessment.Level
    private typealias Competency = PlanningAssessment.Competency

    private func competency(_ id: PlanningAssessment.CompetencyID = .outcomesCompletion,
                            levels: [Level]) -> Competency {
        Competency(id: id, summary: "Cedar defines the expected export result.",
                   sources: [.init(title: "Practice guide", url: "https://code.claude.com/docs/en/best-practices", note: "Define checks.")],
                   criteria: .init(high: "Result and check are connected.", medium: "Result is defined.", low: "Only a change is named."),
                   tasks: levels.enumerated().map { index, level in
                       .init(taskID: "task-\(index)", project: "Cedar", level: level,
                             observation: "Export output was specified.", rationale: "A matching check was requested.",
                             evidence: [.init(tool: "codex", sessionId: "fictional-session", date: "2026-10-22",
                                              note: "Export acceptance check", project: "Cedar")])
                   }, solution: "Connect the expected result to an observable check.")
    }

    private func assessment(_ levels: [[Level]]) -> PlanningAssessment {
        PlanningAssessment(competencies: zip(PlanningAssessment.CompetencyID.allCases, levels).map {
            competency($0.0, levels: $0.1)
        })
    }

    private func legacyCard() throws -> ScoreCard {
        try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
    }

    @Test func legacyCardsDecodeWithoutPlanningAndNewDetailsRoundTrip() throws {
        var card = try legacyCard()
        #expect(card.dimensions[0].planning == nil)
        let legacyData = try JSONEncoder().encode(card)
        try card.normalizePlanningAssessment()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let original = try JSONDecoder().decode(ScoreCard.self, from: legacyData)
        #expect(try encoder.encode(card) == encoder.encode(original))
        card.dimensions[0].planning = assessment([[.high], [.medium], [.low], [.unknown]])
        let decoded = try JSONDecoder().decode(ScoreCard.self, from: JSONEncoder().encode(card))
        let planning = try #require(decoded.dimensions[0].planning)
        #expect(planning.competencies.count == 4)
        #expect(planning.competencies[0].criteria.high == "Result and check are connected.")
        #expect(planning.competencies[0].sources[0].url == "https://code.claude.com/docs/en/best-practices")
        #expect(planning.competencies[0].tasks[0].evidence[0].sessionId == "fictional-session")
    }

    @Test func thresholdsUseIndependentTaskCountsAtExactBoundaries() {
        let high = competency(levels: [.high, .high, .high, .high, .medium])
        #expect(high.level == .high)
        #expect(high.assessedCount == 5)
        #expect(competency(levels: [.high, .high, .high, .medium, .medium]).level == .medium)
        #expect(competency(levels: [.low, .low, .medium, .high]).level == .low)
        #expect(competency(levels: [.low, .low, .medium, .medium, .high]).level == .medium)
    }

    @Test func missingEvidenceAndNotApplicableTasksDoNotBecomeLow() {
        let mixed = competency(levels: [.high, .high, .high, .high, .medium, .unknown, .notApplicable])
        #expect(mixed.level == .high)
        #expect(mixed.assessedCount == 5)
        #expect(mixed.unknownCount == 1)
        #expect(mixed.notApplicableCount == 1)
        #expect(competency(levels: [.unknown]).level == .unknown)
        #expect(competency(levels: [.notApplicable]).level == .notApplicable)
        #expect(competency(levels: [.unknown, .notApplicable]).level == .unknown)
        #expect(competency(levels: []).level == .unknown)
    }

    @Test func rejectsMissingOrDuplicateCompetenciesAndRepeatedTasks() throws {
        var planning = assessment([[.high], [.medium], [.low], [.unknown]])
        try planning.validate()
        planning.competencies[0].tasks.append(planning.competencies[0].tasks[0])
        #expect(throws: PlanningAssessment.ValidationError.self) { try planning.validate() }
        planning = assessment([[.high], [.medium], [.low], [.unknown]])
        planning.competencies[3].id = .constraints
        #expect(throws: PlanningAssessment.ValidationError.self) { try planning.validate() }
        planning.competencies.removeLast()
        #expect(throws: PlanningAssessment.ValidationError.self) { try planning.validate() }
    }

    @Test func normalizesPlanningScoreAndLegacyReadersWhilePreservingOtherDimensions() throws {
        var card = try legacyCard()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let othersBefore = try encoder.encode(Array(card.dimensions.dropFirst()))
        card.dimensions[0].planning = assessment([[.high], [.medium], [.low], [.unknown]])
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].score == 5)
        #expect(card.dimensions[0].status == .scored)
        #expect(card.dimensions[0].strengths?.count == 1)
        #expect(card.dimensions[0].saw?.components(separatedBy: "\n\n").count == 2)
        #expect(card.dimensions[0].solutionSteps?.count == 2)
        #expect(card.dimensions[0].reason.contains("https://code.claude.com/docs/en/best-practices"))
        #expect(card.dimensions[0].reason.contains("fictional-session"))
        #expect(try encoder.encode(Array(card.dimensions.dropFirst())) == othersBefore)
        let firstNormalized = try encoder.encode(card)
        try card.normalizePlanningAssessment()
        #expect(try encoder.encode(card) == firstNormalized)
        #expect(card.scope.limits.filter { $0.hasPrefix("Planning & Specs calculated audit:") }.count == 1)
    }

    @Test func scoreKeepsUnknownInDenominatorAndExcludesOnlyNotApplicable() throws {
        var card = try legacyCard()
        card.dimensions[0].planning = assessment([[.high], [.high], [.unknown], [.notApplicable]])
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].score == 7)
        card.dimensions[0].planning = assessment([[.unknown], [.unknown], [.unknown], [.unknown]])
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].score == 0)
        #expect(card.dimensions[0].status == .scored)
        card.dimensions[0].planning = assessment([[.notApplicable], [.notApplicable], [.notApplicable], [.notApplicable]])
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].score == nil)
        #expect(card.dimensions[0].status == .notAssessable)
    }

    @Test func halfPointsRoundUpAndInvalidDataCannotPartlyNormalizeCard() throws {
        var card = try legacyCard()
        card.dimensions[0].planning = assessment([[.high], [.medium], [.high], [.low]])
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].score == 8)
        var invalid = assessment([[.low], [.low], [.low], [.low]])
        invalid.competencies[0].tasks.append(invalid.competencies[0].tasks[0])
        card.dimensions[0].planning = invalid
        #expect(throws: PlanningAssessment.ValidationError.self) { try card.normalizePlanningAssessment() }
        #expect(card.dimensions[0].score == 8)
    }

    @Test func assessedTasksRequireEvidenceWhileUnassessedTasksMayHaveNone() throws {
        for level in [Level.high, .medium, .low] {
            var planning = assessment([[level], [.unknown], [.notApplicable], [.unknown]])
            planning.competencies[0].tasks[0].evidence = []
            #expect(throws: PlanningAssessment.ValidationError.self) { try planning.validate() }
        }
        var planning = assessment([[.high], [.unknown], [.notApplicable], [.unknown]])
        for index in 1..<4 {
            planning.competencies[index].tasks[0].evidence = []
        }
        try planning.validate()
    }

    @Test func everyObservedIndependentTaskRemainsInTheJudgingSet() throws {
        let levels: [Level] = [.high, .high, .high, .high, .high, .high, .medium, .medium, .low, .low]
        let planning = assessment([levels, [.unknown], [.unknown], [.unknown]])
        try planning.validate()
        let value = planning.competencies[0]
        #expect(value.tasks.count == 10)
        #expect(value.assessedCount == 10)
        #expect(value.highCount == 6)
        #expect(value.level == .medium)
    }

    @Test func explanationIsOptionalOnOlderDetailsAndRoundTripsOnNewDetails() throws {
        var planning = assessment([[.high], [.medium], [.low], [.unknown]])
        let old = try JSONDecoder().decode(PlanningAssessment.self, from: JSONEncoder().encode(planning))
        #expect(old.competencies[0].explanation == nil)
        planning.competencies[0].explanation = .init(sourceBasis: "The guide recommends a real result check.",
            criteria: "High connects result and check; medium leaves the check open; low names only a change.",
            observedBehavior: "Cedar's export request connects its result to a check.",
            overallJudgment: "The single assessed task is high.")
        let decoded = try JSONDecoder().decode(PlanningAssessment.self, from: JSONEncoder().encode(planning))
        let explanation = try #require(decoded.competencies[0].explanation)
        #expect(explanation.sourceBasis == planning.competencies[0].explanation?.sourceBasis)
        #expect(explanation.criteria == planning.competencies[0].explanation?.criteria)
        #expect(explanation.observedBehavior == planning.competencies[0].explanation?.observedBehavior)
        #expect(explanation.overallJudgment == planning.competencies[0].explanation?.overallJudgment)
        let markdown = decoded.markdown(language: "en")
        #expect(markdown.contains(explanation.sourceBasis))
        #expect(markdown.contains(explanation.criteria))
        #expect(markdown.contains(explanation.observedBehavior))
        #expect(markdown.contains(explanation.overallJudgment))
    }

    @Test func sourcesAcceptOnlyTheFiveCanonicalRubricURLs() throws {
        let urls = [
            "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/principle-prove-it-works/SKILL.md",
            "https://raw.githubusercontent.com/cursor/plugins/main/pstack/skills/sharpen/SKILL.md",
            "https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md",
            "https://code.claude.com/docs/en/best-practices",
            "https://raw.githubusercontent.com/github/spec-kit/main/templates/spec-template.md"
        ]
        var planning = assessment([[.high], [.medium], [.low], [.unknown]])
        for url in urls {
            planning.competencies[0].sources[0].url = url
            try planning.validate()
        }
        for url in ["https://example.org/guide", urls[3] + "?redirect=example.org", "javascript:alert(1)"] {
            planning.competencies[0].sources[0].url = url
            #expect(throws: PlanningAssessment.ValidationError.self) { try planning.validate() }
        }
    }

    @Test func recalculatedScoreInvalidatesConflictingNarrativeAndPreservesOtherDimensions() throws {
        var card = try legacyCard()
        card.language = "ko"
        card.dimensions[0].score = 10
        card.dimensions[0].headline = "모든 역량이 상입니다."
        card.dimensions[0].changeReason = "모든 역량이 개선됐습니다."
        card.dimensions[0].impact = "더 개선할 부분이 없습니다."
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let others = try encoder.encode(Array(card.dimensions.dropFirst()))
        card.dimensions[0].planning = assessment([[.high], [.medium], [.low], [.unknown]])

        try card.normalizePlanningAssessment()

        #expect(card.dimensions[0].score == 5)
        #expect(card.dimensions[0].headline == "상 1, 중 1, 하 1, 미확인 1, 해당 없음 0")
        #expect(card.dimensions[0].changeReason == nil)
        #expect(card.dimensions[0].impact == nil)
        #expect(try encoder.encode(Array(card.dimensions.dropFirst())) == others)
    }

    @Test func matchingScoreKeepsNarrativeButImpactRequiresObservedGap() throws {
        var card = try legacyCard()
        card.dimensions[0].planning = assessment([[.high], [.medium], [.low], [.unknown]])
        card.dimensions[0].score = 5
        card.dimensions[0].headline = "The evidence supports a mixed result."
        card.dimensions[0].changeReason = "A completion check is now defined."
        card.dimensions[0].impact = "Some tasks still lack completion checks."
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].headline == "The evidence supports a mixed result.")
        #expect(card.dimensions[0].changeReason == "A completion check is now defined.")
        #expect(card.dimensions[0].impact == "Some tasks still lack completion checks.")

        card.dimensions[0].planning = assessment([[.high], [.high], [.high], [.high]])
        card.dimensions[0].score = 10
        try card.normalizePlanningAssessment()
        #expect(card.dimensions[0].impact == nil)
    }

    @Test func markdownSolutionsMatchObservedGapsAndUseTheCardLanguage() {
        var planning = assessment([[.high], [.medium], [.low], [.unknown]])
        for index in planning.competencies.indices {
            planning.competencies[index].solution = "solution-\(index)"
        }
        let korean = planning.markdown(language: "ko")
        #expect(korean.contains("**해결 방법**"))
        #expect(!korean.contains("**Solution**"))
        #expect(!korean.contains("solution-0"))
        #expect(korean.contains("solution-1"))
        #expect(korean.contains("solution-2"))
        #expect(!korean.contains("solution-3"))
        #expect(planning.markdown(language: "en").contains("**Solution**"))
    }
}
