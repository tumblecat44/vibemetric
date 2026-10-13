import Darwin
import Foundation
import XCTest
@testable import VibemetricCore

/// Checks that the scanner frees each file's temporary objects before the scan ends.
///
/// Each fixture file has rows with a large payload that the parser ignores, so a session keeps almost none of it.
/// The scan has 16 files for each worker thread.
/// - If the scanner frees each file's temporaries before the next file, it holds at most about one file per
///   worker at a time. That is 1/16 of the payload, plus parser overhead.
/// - If it keeps them until the scan ends, it holds the whole payload at the end.
/// The limit is half the payload, between those two cases. It scales with the core count, so no absolute
/// memory number is involved.
final class ScannerMemoryTests: XCTestCase {
    private let payloadRowsPerFile = 24
    private let payloadBytesPerRow = 64 * 1024  // about 1.5 MiB of ignored payload in each file

    func testScanFreesEachFilesTemporariesBeforeTheScanEnds() throws {
        let workers = ProcessInfo.processInfo.activeProcessorCount
        let fileCount = workers * 16
        let warmUp = try makeTranscripts(count: 1)
        let transcripts = try makeTranscripts(count: fileCount)
        defer {
            try? FileManager.default.removeItem(at: warmUp)
            try? FileManager.default.removeItem(at: transcripts)
        }

        // The first scan creates long-lived objects such as date formatters and regexes. Do it before the
        // measurement so that those objects are not counted as growth.
        _ = peakGrowthWhileScanning(warmUp, expectedSessions: 1)
        let growth = peakGrowthWhileScanning(transcripts, expectedSessions: fileCount)

        let payload = UInt64(fileCount * payloadRowsPerFile * payloadBytesPerRow)
        XCTAssertLessThan(growth, payload / 2,
                          "Peak grew \(mib(growth)) MiB while scanning \(mib(payload)) MiB of ignored payload in \(fileCount) files")
    }

    // MARK: - Fixture

    /// Writes `count` Claude Code transcripts. Each has one real user turn and payload rows that the parser ignores.
    private func makeTranscripts(count: Int) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let project = root.appendingPathComponent("-Users-me-app")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let payload = String(repeating: "x", count: payloadBytesPerRow)
        let ignoredRow = #"{"type":"progress","timestamp":"2026-09-01T10:00:01.000Z","data":""# + payload + #""}"#
        let userRow = #"{"type":"user","cwd":"/Users/me/app","timestamp":"2026-09-01T10:00:00.000Z","message":{"role":"user","content":"Fix the build."}}"#
        let body = Data(([userRow] + Array(repeating: ignoredRow, count: payloadRowsPerFile)).joined(separator: "\n").utf8)
        for i in 0..<count {
            try body.write(to: project.appendingPathComponent("s\(i).jsonl"))
        }
        return root
    }

    // MARK: - Measurement

    /// Peak physical footprint above the starting value while `Scanner.scan` runs.
    private func peakGrowthWhileScanning(_ root: URL, expectedSessions: Int) -> UInt64 {
        // concurrentPerform also runs iterations on this thread. This outer pool frees whatever stays
        // on this thread after the scan, so the next measurement starts clean.
        autoreleasepool {
            let baseline = physFootprint()
            let sampler = PeakSampler()
            sampler.start()
            let scan = Scanner.scan(sources: [TranscriptSource(tool: .claudeCode, root: root)])
            let peak = sampler.stop()
            XCTAssertEqual(scan.sessions.count, expectedSessions)
            return peak > baseline ? peak - baseline : 0
        }
    }

    private func mib(_ bytes: UInt64) -> UInt64 { bytes / (1024 * 1024) }
}

/// Reads the physical footprint (the value Activity Monitor shows as Memory) every millisecond and keeps the highest value.
private final class PeakSampler: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: UInt64 = 0
    private var running = true
    private let done = DispatchSemaphore(value: 0)

    func start() {
        peak = physFootprint()
        Thread.detachNewThread { [self] in
            while lock.withLock({ running }) {
                let now = physFootprint()
                lock.withLock { peak = max(peak, now) }
                usleep(1000)
            }
            done.signal()
        }
    }

    func stop() -> UInt64 {
        let now = physFootprint()
        lock.withLock { running = false; peak = max(peak, now) }
        done.wait()
        return lock.withLock { peak }
    }
}

private func physFootprint() -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
}
