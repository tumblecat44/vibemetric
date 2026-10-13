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
    public var sessions: [Session]
    public var sources: [TranscriptSource]
    public var duration: TimeInterval

    public var projects: [String] { Array(Set(sessions.map(\.project))).sorted() }

    public func sessions(for tool: AgentTool) -> [Session] { sessions.filter { $0.tool == tool } }

    public var dateRange: ClosedRange<Date>? {
        let dates = sessions.compactMap(\.start)
        guard let lo = dates.min(), let hi = sessions.compactMap(\.end).max() else { return nil }
        return lo...max(lo, hi)
    }
}

public enum Scanner {
    public static func scan(sources: [TranscriptSource] = TranscriptSource.defaults()) -> ScanResult {
        let started = Date()
        var jobs: [(agentTool: AgentTool, transcriptFile: URL)] = []
        for source in sources {
            jobs += transcriptFiles(for: source).map { (source.tool, $0) }
        }

        let lock = NSLock()
        var sessions: [Session] = []
        DispatchQueue.concurrentPerform(iterations: jobs.count) { i in
            // Free each file's temporary Foundation objects before this thread takes the next file.
            autoreleasepool {
                let (agentTool, transcriptFile) = jobs[i]
                guard let session = annotatedSession(from: transcriptFile, agentTool: agentTool) else { return }
                lock.lock(); sessions.append(session); lock.unlock()
            }
        }
        sessions.sort { ($0.start ?? .distantPast) < ($1.start ?? .distantPast) }
        return ScanResult(sessions: sessions, sources: sources, duration: Date().timeIntervalSince(started))
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
