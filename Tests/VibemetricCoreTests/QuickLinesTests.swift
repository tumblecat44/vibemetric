import Foundation
import Testing
@testable import VibemetricCore

/// Each category's quick good and gap lines in the category list; older cards keep their issue line there.
struct QuickLinesTests {
    @Test func everyDimensionIsAskedForAGoodAndAGapLine() {
        for dimension in Dimension.allCases {
            let schema = JSONSchema.cardDimension(dimension)
            #expect(schema.contains("\"goodLine\"") && schema.contains("\"gapLine\""))
        }
    }

    @Test func olderCardsHaveNoQuickLines() throws {
        let card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        #expect(card.dimensions.allSatisfy { $0.goodLine == nil && $0.gapLine == nil })
    }

    @Test func quickLinesRoundTrip() throws {
        var card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        card.dimensions[0].goodLine = "You say clearly what you want built."
        card.dimensions[0].gapLine = "You rarely say how to check it's done."
        let decoded = try JSONDecoder().decode(ScoreCard.self, from: JSONEncoder().encode(card))
        #expect(decoded.dimensions[0].goodLine == card.dimensions[0].goodLine)
        #expect(decoded.dimensions[0].gapLine == card.dimensions[0].gapLine)
    }

    @Test func onlyLinesWellPastTheirLengthAreRewritten() throws {
        var card = try JSONDecoder().decode(ScoreCard.self, from: Data(CoreTests.sampleCard.utf8))
        card.dimensions[0].goodLine = "You say clearly what you want built."
        card.dimensions[0].gapLine = "Bug fixes in three projects land without any new test, and the main pipeline has no eval at all."
        card.overview = [.init(tone: .good, text: "You check your work.")]
        let long = Assessor.longLines(in: card)
        #expect(long.map(\.id) == ["dimensions.0.gapLine"])

        Assessor.apply([.init(id: "dimensions.0.gapLine", text: " Fixes often ship without a new test. "),
                        .init(id: "dimensions.99.gapLine", text: "Ignored."), .init(id: "overview.0", text: "")], to: &card)
        #expect(card.dimensions[0].gapLine == "Fixes often ship without a new test.")
        #expect(card.overview?.first?.text == "You check your work.")
        #expect(Assessor.longLines(in: card).isEmpty)
    }
}
