import Foundation

/// Where each tool keeps its transcripts. Only transcript directories are ever read.
public struct TranscriptSource: Codable, Sendable {
    public var tool: AgentTool
    public var root: URL

    public static func defaults(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [TranscriptSource] {
        [
            TranscriptSource(tool: .claudeCode, root: home.appendingPathComponent(".claude/projects")),
            TranscriptSource(tool: .codex, root: home.appendingPathComponent(".codex/sessions")),
        ]
    }
}

public struct ScanResult: Sendable {
    public var sessions: [SessionSummary]
    public var sources: [TranscriptSource]
    public var duration: TimeInterval
    /// Transcript files parsed in this scan; the rest came from the cache.
    public var parsedFiles = 0

    public init(sessions: [SessionSummary], sources: [TranscriptSource], duration: TimeInterval, parsedFiles: Int = 0) {
        self.sessions = sessions
        self.sources = sources
        self.duration = duration
        self.parsedFiles = parsedFiles
    }

    public var projects: [String] { Array(Set(sessions.map(\.project))).sorted() }

    public func sessions(for tool: AgentTool) -> [SessionSummary] { sessions.filter { $0.tool == tool } }

    public var dateRange: ClosedRange<Date>? {
        let dates = sessions.compactMap(\.start)
        guard let lo = dates.min(), let hi = sessions.compactMap(\.end).max() else { return nil }
        return lo...max(lo, hi)
    }
}

public enum Scanner {
    /// Bump when parsing, signals or summaries change in a way the app's build number wouldn't catch.
    /// The app's build and executable date are part of the cache version too, so every update and every
    /// rebuild starts from a fresh parse.
    static let cacheFormat = 1

    /// Parses every transcript, or, with `cache`, only transcripts that are new or changed since the last scan,
    /// taking the rest from the cache file and rewriting it. Either way the result covers every session.
    public static func scan(sources: [TranscriptSource] = TranscriptSource.defaults(), cache: URL? = nil) -> ScanResult {
        let started = Date()
        let version = cacheVersion()
        var cached = cache.flatMap { ScanCache.load(from: $0, version: version) } ?? ScanCache(version: version)
        var next = ScanCache(version: version)

        var jobs: [(agentTool: AgentTool, transcriptFile: URL, fingerprint: String)] = []
        for source in sources {
            for file in transcriptFiles(for: source) {
                let fingerprint = fingerprint(of: file, tool: source.tool)
                if let entry = cached.entries.removeValue(forKey: file.path), entry.fingerprint == fingerprint {
                    next.entries[file.path] = entry
                } else {
                    jobs.append((source.tool, file, fingerprint))
                }
            }
        }

        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: jobs.count) { i in
            // Free each file's temporary Foundation objects before this thread takes the next file.
            autoreleasepool {
                let (agentTool, transcriptFile, fingerprint) = jobs[i]
                let summary = annotatedSession(from: transcriptFile, agentTool: agentTool).map(SessionSummary.init)
                lock.lock(); next.entries[transcriptFile.path] = ScanCache.Entry(fingerprint: fingerprint, summary: summary); lock.unlock()
            }
        }
        // Rewrite when anything was parsed or a transcript disappeared.
        if let cache, !jobs.isEmpty || !cached.entries.isEmpty { next.save(to: cache) }

        let sessions = next.entries.values.compactMap(\.summary)
            .sorted { ($0.start ?? .distantPast, $0.file.path) < ($1.start ?? .distantPast, $1.file.path) }
        return ScanResult(sessions: sessions, sources: sources, duration: Date().timeIntervalSince(started), parsedFiles: jobs.count)
    }

    /// The full session behind a summary, every event included, parsed again from its transcript.
    /// Nil when the transcript is gone or no longer parses.
    public static func fullSession(for summary: SessionSummary) -> Session? {
        annotatedSession(from: summary.file, agentTool: summary.tool)
    }

    /// Size and modification date of the transcript, plus each Claude Code subagent transcript folded into it.
    static func fingerprint(of file: URL, tool: AgentTool) -> String {
        func stamp(_ url: URL) -> String {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return "\(values?.fileSize ?? -1)@\(values?.contentModificationDate?.timeIntervalSinceReferenceDate ?? -1)"
        }
        var parts = [stamp(file)]
        if tool == .claudeCode {
            let childDir = file.deletingPathExtension().appendingPathComponent("subagents")
            let children = (try? FileManager.default.contentsOfDirectory(at: childDir, includingPropertiesForKeys: nil)) ?? []
            for child in children.filter({ $0.pathExtension == "jsonl" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                parts.append(child.lastPathComponent + ":" + stamp(child))
            }
        }
        return parts.joined(separator: "|")
    }

    static func cacheVersion(bundle: Bundle = .main) -> String {
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "none"
        let executable = bundle.executableURL.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]) }?
            .contentModificationDate?.timeIntervalSinceReferenceDate ?? 0
        return "\(cacheFormat)-\(build)-\(executable)"
    }

    /// Parses one transcript file and annotates its signals. Returns nil for unreadable files and assessment runs.
    static func annotatedSession(from transcriptFile: URL, agentTool: AgentTool) -> Session? {
        let parsed: Session?
        switch agentTool {
        case .claudeCode: parsed = ClaudeCodeParser.parse(file: transcriptFile)
        case .codex: parsed = CodexParser.parse(file: transcriptFile)
        }
        guard var session = parsed, !isAssessmentRun(session) else { return nil }
        SignalExtractor.annotate(&session)
        return session
    }

    /// Fork rollouts may omit the original prompt, so recognize the app-owned workspace too.
    static func isAssessmentRun(_ s: Session) -> Bool {
        if let cwd = s.cwd {
            let path = URL(fileURLWithPath: cwd).standardizedFileURL.path
            if [false, true].contains(where: {
                path.hasPrefix(EvidencePack.savedPacksDirectory(isDev: $0).standardizedFileURL.path + "/")
            }) { return true }
        }
        let first = s.events.lazy.compactMap { e -> String? in if case let .user(t) = e.kind { return t }; return nil }.first ?? ""
        return first.prefix(400).localizedCaseInsensitiveContains("AI Native Score")
    }

    static func transcriptFiles(for source: TranscriptSource) -> [URL] {
        guard let walker = FileManager.default.enumerator(at: source.root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var files: [URL] = []
        for case let url as URL in walker where url.pathExtension == "jsonl" {
            switch source.tool {
            case .claudeCode:
                // Subagent transcripts are folded into their parent session by the parser.
                if url.pathComponents.contains("subagents") { continue }
                // Claude Code keeps auto-memory and other sidecar folders under projects; only session files count.
                if url.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL != source.root.standardizedFileURL { continue }
            case .codex:
                if !url.lastPathComponent.hasPrefix("rollout-") { continue }
            }
            files.append(url)
        }
        return files
    }
}
