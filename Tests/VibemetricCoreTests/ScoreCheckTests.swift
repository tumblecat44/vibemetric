import Foundation
import Testing
@testable import VibemetricCore

/// The rubric's checks behind each score, as the app reads and shows them.
struct ScoreCheckTests {
    @Test func everyCheckInTheAppIsDefinedInTheRubric() {
        let rubric = Assessor.rubric
        #expect(Set(ScoreCheck.allIDs).count == ScoreCheck.allIDs.count, "Check IDs are unique across dimensions")
        for dimension in Dimension.allCases {
            let definitions = ScoreCheck.definitions(for: dimension)
            #expect((2...4).contains(definitions.count), "\(dimension.rawValue) has two to four checks")
            for definition in definitions {
                #expect(rubric.contains("- `\(definition.id)` · **\(definition.title).**"), "\(definition.id) matches the rubric")
            }
        }
        #expect(rubric.components(separatedBy: "**Checks:**").count - 1 == Dimension.allCases.count)
    }

    @Test func theSchemaAsksForTheLevelsAndChecks() {
        let schema = JSONSchema.scoreCard
        for field in ["\"levelNow\"", "\"nextLevel\"", "\"checks\"", "\"not_seen\"", "\"user_outcome\"", "\"routing_by_default\""] {
            #expect(schema.contains(field))
        }
    }

    @Test func eachDimensionKeepsOnlyItsOwnChecksInRubricOrder() throws {
        var card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        let index = card.dimensions.firstIndex { $0.dimension == .testingEvals }!
        card.dimensions[index].checks = [
            ScoreCheck(id: "automatic_checks", status: .notMet, note: "No hook runs the tests.", seen: 0, of: 6),
            ScoreCheck(id: "fit_model", status: .met, note: "Belongs to Efficiency & Cost."),
            ScoreCheck(id: "real_checks", status: .met, note: "Checked after most changes.", seen: 2, of: 2),
            ScoreCheck(id: "real_checks", status: .partly, note: "A duplicate."),
        ]
        card.normalizeChecks()
        let checks = try #require(card.dimensions[index].checks)
        #expect(checks.map(\.id) == ["real_checks", "automatic_checks"], "Own checks only, once each, in rubric order")
        #expect(checks[0].status == .met && checks[0].count == nil && checks[0].seen == nil, "A count from 2 tasks is dropped")
        #expect(checks[1].count == "0 of 6")
    }

    @Test func countsNeedEnoughTasksAndMakeSense() {
        #expect(ScoreCheck(id: "a", status: .met, note: "", seen: 9, of: 12).count == "9 of 12")
        #expect(ScoreCheck(id: "a", status: .met, note: "", seen: 2, of: 2).count == nil)
        #expect(ScoreCheck(id: "a", status: .met, note: "", seen: 5, of: 4).count == nil)
        #expect(ScoreCheck(id: "a", status: .notSeen, note: "").count == nil)
        #expect(ScoreCheck.Status.notSeen.label == "Not enough evidence")
    }

    @Test(arguments: [(0, 1), (1, 3), (2, 3), (5, 7), (6, 7), (8, 9), (9, 10)])
    func theNextLevelIsTheAnchorAbove(_ entry: (Int, Int)) {
        #expect(ScoreCheck.nextAnchor(after: entry.0) == entry.1)
    }

    @Test func theTopScoreHasNoNextLevel() {
        #expect(ScoreCheck.nextAnchor(after: 10) == nil)
    }

    @Test func olderCardsWithoutChecksStillDecodeAndRoundTrip() throws {
        let card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        #expect(card.dimensions.allSatisfy { $0.checks == nil && $0.levelNow == nil && $0.nextLevel == nil })
        var updated = card
        updated.dimensions[0].levelNow = "Explains the end user's situation and result."
        updated.dimensions[0].nextLevel = "Also states how completion will be checked."
        updated.dimensions[0].checks = [ScoreCheck(id: "user_outcome", status: .met, note: "Cedar's export request named its user.")]
        let decoded = try JSONDecoder().decode(ScoreCard.self, from: JSONEncoder().encode(updated))
        #expect(decoded.dimensions[0].checks == updated.dimensions[0].checks)
        #expect(decoded.dimensions[0].levelNow == updated.dimensions[0].levelNow)
    }
}
