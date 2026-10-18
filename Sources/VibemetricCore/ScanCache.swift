import Foundation

/// The scan's index cards: one summary per transcript file, keyed by path, with the fingerprint it was made
/// from. A different version (new parser, new app build) or an unreadable file means starting over.
struct ScanCache: Codable {
    struct Entry: Codable {
        var fingerprint: String
        /// Nil for transcripts that aren't sessions to score (empty, or one of Vibemetric's own runs).
        var summary: SessionSummary?
    }

    var version: String
    var entries: [String: Entry] = [:]

    static func load(from url: URL, version: String) -> ScanCache? {
        guard let data = try? Data(contentsOf: url),
              let cache = try? JSONDecoder().decode(ScanCache.self, from: data), cache.version == version else { return nil }
        return cache
    }

    func save(to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
