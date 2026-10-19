import Foundation
import Testing
@testable import VibemetricAppKit

/// The running screen's percentage: stage by stage, counted by digests read, never backwards, 100% only when done.
struct ScoreProgressTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func movesThroughTheStagesWithoutGoingBackwards() {
        var progress = ScoreProgress(started: start, wrapUpAfter: 390)
        var last = progress.percent(at: start)
        func check(_ seconds: TimeInterval) {
            let now = progress.percent(at: start.addingTimeInterval(seconds))
            #expect(now >= last, "at \(seconds)s")
            last = now
        }
        #expect(last == 0)
        check(10)
        #expect(last < 10, "Preparing stays under 10%")

        progress.startReading(digests: 150, at: start.addingTimeInterval(15))
        check(15)
        #expect(last >= 10)
        for i in 0..<35 { progress.noteRead("Read cc-\(i)abcdef.md", at: start.addingTimeInterval(20)) }
        check(20)
        #expect(last >= 47, "Half of the 70-digest target read")

        progress.startWriting(at: start.addingTimeInterval(200))
        check(200)
        #expect(last >= 85)
        check(600)
        #expect(last <= 99, "Never 100% before the card arrives")

        progress.finish()
        #expect(progress.percent(at: start.addingTimeInterval(601)) == 100)
    }

    @Test func countsEachDigestOnceFromEitherEngine() {
        var progress = ScoreProgress(started: start)
        progress.startReading(digests: 4, at: start)
        progress.noteRead("Read cc-1a2b3c4d5e6f.md")
        progress.noteRead("Read cc-1a2b3c4d5e6f.md")
        progress.noteRead("Grep overview.md")
        progress.noteRead("sed -n 1,200p sessions/codex-0199abcd.md sessions/cc-77aa.md")
        #expect(progress.digestsRead.count == 3)
        #expect(progress.label == "Reading sessions · 3 of 4")
        progress.noteRead("cat sessions/codex-0199ffff.md")
        #expect(progress.stage == .writing, "All four read, so the card is being written")
    }

    @Test func timeKeepsTheBarMovingWhileTheEngineThinks() {
        var progress = ScoreProgress(started: start, wrapUpAfter: 390)
        progress.startReading(digests: 150, at: start)
        #expect(progress.percent(at: start.addingTimeInterval(195)) >= 47, "Halfway to the wrap-up time")
        #expect(progress.percent(at: start.addingTimeInterval(2000)) == 85, "Reading tops out at 85%")
    }
}
