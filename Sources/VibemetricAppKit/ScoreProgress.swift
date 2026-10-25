import Foundation
import VibemetricCore

/// How far a score has got, as a percentage the running screen can show.
///
/// A score has three stages. Preparing (scanning and writing the evidence pack) fills 0–10%. Reading fills 10–85%:
/// the digests read so far out of the reading target, or the time spent out of the time before the wrap-up, whichever
/// is further, so the bar keeps moving while the engine reads other files or thinks. Writing the card fills 85–99%,
/// easing toward 99% until the card arrives. Each stage only grows with time and reads, and starts where the one before
/// can end, so the bar never moves backwards; it reaches 100% only when the score is done.
struct ScoreProgress {
    enum Stage: Equatable { case preparing, reading, writing, done }

    private(set) var stage: Stage = .preparing
    private(set) var digestsRead: Set<String> = []
    /// Digests the engine is asked to read: all of them up to `AssessmentOptions.readingTarget`.
    private(set) var target = AssessmentOptions.readingTarget
    private var started: Date
    private var readingStarted: Date?
    private var writingStarted: Date?
    private var wrapUpAfter: TimeInterval

    init(started: Date = Date(), wrapUpAfter: TimeInterval = AssessmentOptions().wrapUpAfter) {
        self.started = started
        self.wrapUpAfter = wrapUpAfter
    }

    /// The evidence pack is ready and the engine starts reading it.
    mutating func startReading(digests: Int, at now: Date = Date()) {
        target = max(1, min(digests, AssessmentOptions.readingTarget))
        readingStarted = now
        stage = .reading
    }

    /// One reading step from the engine, such as "Read cc-1a2b3c4d5e6f.md" or a `cat sessions/...` command.
    mutating func noteRead(_ what: String, at now: Date = Date()) {
        guard stage == .reading else { return }
        for match in what.matches(of: Self.digestName) { digestsRead.insert(String(what[match.range])) }
        if digestsRead.count >= target { startWriting(at: now) }
    }

    /// The engine is writing the card: it read its target, or reached the reading time limit.
    mutating func startWriting(at now: Date = Date()) {
        guard stage == .preparing || stage == .reading else { return }
        stage = .writing
        writingStarted = now
    }

    mutating func finish() { stage = .done }

    /// The percentage to show at `now`, from 0 to 100.
    func percent(at now: Date = Date()) -> Int { Int(fraction(at: now) * 100) }

    func fraction(at now: Date) -> Double {
        switch stage {
        case .preparing:
            // Preparing usually takes seconds; ease toward 9% so it moves without overshooting.
            return 0.10 * ease(now.timeIntervalSince(started), over: 20) * 0.9
        case .reading:
            let byDigests = Double(digestsRead.count) / Double(target)
            let byTime = now.timeIntervalSince(readingStarted ?? now) / wrapUpAfter
            return 0.10 + 0.75 * min(max(byDigests, byTime), 1)
        case .writing:
            return 0.85 + 0.14 * ease(now.timeIntervalSince(writingStarted ?? now), over: 60)
        case .done:
            return 1
        }
    }

    /// 0 at the start, about 63% after `seconds`, approaching 1.
    private func ease(_ elapsed: TimeInterval, over seconds: TimeInterval) -> Double {
        1 - exp(-max(elapsed, 0) / seconds)
    }

    /// Digest file names from `EvidencePack`: `cc-<id>.md` or `codex-<id>.md`.
    private static let digestName = try! Regex(#"(?:cc|codex)-[A-Za-z0-9_-]+\.md"#)

    /// What the running screen says about the current stage.
    var label: String {
        switch stage {
        case .preparing: "Preparing your evidence"
        case .reading: "Reading sessions · \(min(digestsRead.count, target)) of \(target)"
        case .writing: "Writing your score"
        case .done: "Done"
        }
    }
}
