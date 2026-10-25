import Foundation
import Testing
@testable import VibemetricCore

/// The result's opening summary: newer cards mix good and bad points; older cards keep their highlights.
struct SummaryOverviewTests {
    @Test func theScorerIsAskedForFourToSixGoodOrGapPoints() throws {
        let schema = try JSONSerialization.jsonObject(with: Data(JSONSchema.scoreCard.utf8)) as! [String: Any]
        let overview = try #require((schema["properties"] as? [String: Any])?["overview"] as? [String: Any])
        #expect(overview["minItems"] as? Int == 4 && overview["maxItems"] as? Int == 6)
        #expect(JSONSchema.scoreCard.contains("\"gap\"") && JSONSchema.cardFrame.contains("\"overview\""),
                "The card's overall part writes the summary")
    }

    @Test func olderCardsHaveNoOverviewAndKeepTheirHighlights() throws {
        let card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        #expect(card.overview == nil)
        #expect(!MarkdownRenderer.render(card).contains("### Summary"))
    }

    @Test func aNewCardKeepsItsPointsAndTheReportListsThem() throws {
        var card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        card.overview = [.init(tone: .gap, text: "Tests run only when you ask."),
                         .init(tone: .good, text: "You save release steps as a skill.")]
        let decoded = try JSONDecoder().decode(ScoreCard.self, from: JSONEncoder().encode(card))
        #expect(decoded.overview == card.overview)
        let report = MarkdownRenderer.render(decoded)
        #expect(report.contains("### Summary\n\n- ✓ You save release steps as a skill.\n- △ Tests run only when you ask."),
                "Good points come first, then the gaps")
        #expect(decoded.groupedOverview?.map(\.tone) == [.good, .gap])
    }
}
