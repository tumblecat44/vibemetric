import Foundation
import Testing
@testable import VibemetricCore
@testable import VibemetricAppKit

/// An engine that can't score must look that way, and a new install uses the engine that works.
@MainActor
struct EngineReadinessTests {
    private let claude = CLIInstallation(executable: URL(fileURLWithPath: "/fixture/claude"), version: "2.1.308")
    private let codex = CLIInstallation(executable: URL(fileURLWithPath: "/fixture/codex"), version: "0.163.0")

    private func makeModel() -> (AppModel, UserDefaults, String) {
        let name = "engine-readiness-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        return (AppModel(preferences: defaults, startAutomatically: false, history: []), defaults, name)
    }

    /// Claude desktop without the `claude` command: Claude isn't ready, so a new install switches to Codex
    /// without saving that as the person's choice.
    @Test func newInstallPicksTheEngineThatWorks() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }
        #expect(model.engine == .claude)
        model.applyEngineChecks([(.claude, nil, nil, nil), (.codex, codex, true, nil)])
        #expect(model.engine == .codex)
        #expect(model.status(of: .claude) == .notInstalled)
        #expect(model.status(of: .codex) == .ready)
        #expect(defaults.string(forKey: AppModel.engineKey) == nil)
        #expect(model.canStartAssessment == false, "No sessions in this model; readiness alone doesn't start it")
    }

    @Test func savedChoiceStaysAndExplainsTheProblem() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }
        model.engine = .claude
        model.applyEngineChecks([(.claude, nil, nil, nil), (.codex, codex, true, nil)])
        #expect(model.engine == .claude)
        #expect(model.engineProblem == "Claude Code isn't installed")
    }

    @Test func signedOutIsNotReady() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }
        model.engine = .claude
        model.applyEngineChecks([(.claude, claude, false, nil), (.codex, nil, nil, nil)])
        #expect(model.installations[.claude] == nil)
        #expect(model.status(of: .claude) == .signedOut)
        #expect(model.engineProblem == "Claude Code isn't signed in")
    }

    /// When the tool can't say whether it's signed in, scoring isn't blocked.
    @Test func unclearSignInCountsAsReady() {
        let (model, defaults, name) = makeModel()
        defer { defaults.removePersistentDomain(forName: name) }
        model.applyEngineChecks([(.claude, claude, nil, nil), (.codex, nil, nil, "Update Codex CLI")])
        #expect(model.status(of: .claude) == .ready)
        #expect(model.status(of: .codex) == .failed("Update Codex CLI"))
        #expect(model.engineProblem == nil)
    }

    @Test func signInAnswersAreRead() {
        #expect(CLISignIn.claudeSignedIn(Data(#"{"loggedIn":true,"authMethod":"claude.ai"}"#.utf8)) == true)
        #expect(CLISignIn.claudeSignedIn(Data(#"{"loggedIn":false,"authMethod":"none"}"#.utf8)) == false)
        #expect(CLISignIn.claudeSignedIn(Data(#"{"loggedIn":false,"authMethod":"apiKey"}"#.utf8)) == nil)
        #expect(CLISignIn.claudeSignedIn(Data("error: unknown command".utf8)) == nil)
        #expect(CLISignIn.codexSignedIn(status: 0, output: "Logged in using ChatGPT") == true)
        #expect(CLISignIn.codexSignedIn(status: 1, output: "Not logged in") == false)
        #expect(CLISignIn.codexSignedIn(status: 2, output: "error: unrecognized subcommand") == nil)
    }
}
