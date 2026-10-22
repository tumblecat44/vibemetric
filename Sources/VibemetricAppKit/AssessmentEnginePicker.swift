import SwiftUI
import VibemetricCore

/// Home and Settings edit the same saved engine and per-engine model selections.
struct AssessmentEnginePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.textScale) private var scale
    /// Settings shows simple uniform rows (label, then a control of one fixed size); Home keeps the larger cards.
    var compact = false
    /// Compact only: the model description and installation line. The start screen hides them and
    /// shows the installation line only when the engine isn't ready.
    var showsDetails = true

    var body: some View {
        if compact { compactBody } else { fullBody }
    }

    // MARK: Compact rows (Settings)

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            row("Engine", height: 46 * scale) { engineSegments }
            row("Model") { modelDropdown }
            if showsDetails {
                Text("\(modelHelp) Evidence is sent to \(model.engine.provider) using your \(model.engine.name) sign-in, plan or API credits.")
                    .scaledFont(12)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsDetails || model.installations[model.engine] == nil {
                installation
            }
        }
    }

    private var controlWidth: CGFloat { 320 * scale }
    private var controlHeight: CGFloat { 34 * scale }

    private func row<Control: View>(_ label: String, height: CGFloat? = nil, @ViewBuilder control: () -> Control) -> some View {
        FieldRow(label) { control().frame(width: controlWidth, height: height ?? controlHeight) }
    }

    /// Two equal halves in one rounded frame; the selected engine is filled. Each says whether it's ready, so an
    /// engine that can't score doesn't look like one that can.
    private var engineSegments: some View {
        HStack(spacing: 0) {
            ForEach(AssessmentEngine.allCases) { engine in
                let selected = model.engine == engine
                let status = model.status(of: engine)
                Button { model.engine = engine } label: {
                    VStack(spacing: 1) {
                        Text(engine.name)
                            .scaledFont(13, weight: selected ? .semibold : .regular)
                            .foregroundStyle(selected ? Color.white : Theme.ink)
                        Label(statusLabel(status), systemImage: statusSymbol(status))
                            .scaledFont(10, weight: .medium)
                            .foregroundStyle(selected ? Color.white.opacity(0.9) : statusColor(status))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(selected ? Theme.accent : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(engine.name), \(statusLabel(status))")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityIdentifier("engine-\(engine.rawValue)")
            }
        }
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.rule))
        .disabled(model.isRunning)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scoring engine")
    }

    /// The same frame as the engine control, so the two rows line up.
    private var modelDropdown: some View {
        let choices = model.engine == .claude ? ModelChoice.allCases.map(\.name) : CodexModelChoice.allCases.map(\.name)
        let current = model.engine == .claude ? model.model.name : model.codexModel.name
        return Menu {
            ForEach(choices, id: \.self) { title in
                Button(title) {
                    if model.engine == .claude, let choice = ModelChoice.allCases.first(where: { $0.name == title }) {
                        model.model = choice
                    } else if model.engine == .codex, let choice = CodexModelChoice.allCases.first(where: { $0.name == title }) {
                        model.codexModel = choice
                    }
                }
            }
        } label: {
            HStack {
                Text(current).scaledFont(13).foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down").scaledFont(11, weight: .semibold).foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.rule))
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(model.isRunning)
        .accessibilityLabel("Model")
        .accessibilityIdentifier(model.engine == .codex ? "codex-model" : "claude-model")
    }

    // MARK: Full layout (Home)

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Choose what analyzes your records")
                    .scaledFont(14, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                engineControl
                Text("Either engine analyzes both histories.")
                    .scaledFont(12)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                // The dropdown sits next to its label rather than spanning the full width under it.
                HStack(spacing: 12) {
                    Text("Model").scaledFont(14).foregroundStyle(Theme.ink)
                    modelMenu.frame(width: 260 * scale)
                    Spacer(minLength: 0)
                }
                Text(modelHelp)
                    .scaledFont(12)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 30 * scale, alignment: .topLeading)
            }

            installation

            Rectangle().fill(Theme.rule).frame(height: 1).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Uses your \(model.engine.name) sign-in.")
                    .scaledFont(13, weight: .semibold)
                    .foregroundStyle(Theme.ink)
                Text("Evidence is sent to \(model.engine.provider) and uses your plan or API credits.")
                    .scaledFont(12)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Two option cards with a radio mark, so the current engine is obvious at a glance.
    private var engineControl: some View {
        HStack(spacing: 10) {
            ForEach(AssessmentEngine.allCases) { engine in
                let selected = model.engine == engine
                Button { model.engine = engine } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .scaledFont(16)
                            .foregroundStyle(selected ? Theme.accent : Theme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.name)
                                .scaledFont(14, weight: .semibold)
                                .foregroundStyle(Theme.ink)
                            Text("by \(engine.provider)")
                                .scaledFont(11)
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(selected ? Theme.accent.opacity(0.08) : Theme.card,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? Theme.accent : Theme.rule, lineWidth: selected ? 2 : 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.name)
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityIdentifier("engine-\(engine.rawValue)")
            }
        }
        .disabled(model.isRunning)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scoring engine")
        .accessibilityIdentifier("assessment-engine")
        .onMoveCommand { direction in
            guard !model.isRunning else { return }
            switch direction {
            case .left: model.engine = .claude
            case .right: model.engine = .codex
            default: break
            }
        }
    }

    private var modelMenu: some View {
        ModelPopup(
            choices: model.engine == .claude ? ModelChoice.allCases.map(\.name) : CodexModelChoice.allCases.map(\.name),
            selection: Binding(
                get: { model.engine == .claude ? model.model.name : model.codexModel.name },
                set: { title in
                    if model.engine == .claude, let choice = ModelChoice.allCases.first(where: { $0.name == title }) {
                        model.model = choice
                    } else if model.engine == .codex, let choice = CodexModelChoice.allCases.first(where: { $0.name == title }) {
                        model.codexModel = choice
                    }
                }
            ),
            fontSize: 13 * scale,
            enabled: !model.isRunning,
            identifier: model.engine == .codex ? "codex-model" : "claude-model"
        )
        .frame(height: 34 * scale)
    }

    private var modelHelp: String {
        if model.engine == .codex { return model.codexModel.help }
        return model.model == .standard
            ? "Uses Sonnet for this assessment."
            : "Uses \(model.model.name) for this assessment."
    }

    private var installation: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let installation = model.installations[model.engine] {
                    let version = installation.version?
                        .split(whereSeparator: \.isWhitespace)
                        .first(where: { $0.first?.isNumber == true })
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.color(for: .strong))
                        .fixedSize()
                    Text(version.map { "\(model.engine.name) · \($0)" } ?? model.engine.name)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1).truncationMode(.middle)
                        .help(installation.version ?? model.engine.name)
                } else if model.isCheckingEngines {
                    ProgressView().controlSize(.small)
                    Text("Checking installation…").foregroundStyle(Theme.muted)
                } else {
                    Label(setupTitle, systemImage: "exclamationmark.circle.fill")
                        .scaledFont(13, weight: .semibold)
                        .foregroundStyle(Theme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button {
                    Task { await model.refreshEngines() }
                } label: {
                    HStack(spacing: 5) {
                        if model.isCheckingEngines, model.installations[model.engine] != nil {
                            ProgressView().controlSize(.mini)
                        }
                        Text("Check again")
                    }
                }
                .buttonStyle(AssessmentSecondaryButtonStyle())
                .disabled(model.isCheckingEngines || model.isRunning)
                .accessibilityIdentifier("check-engines")
            }
            .scaledFont(12)

            if model.installations[model.engine] == nil, !model.isCheckingEngines { setupGuide }
        }
    }

    // MARK: Engine status

    private func statusLabel(_ status: AppModel.EngineStatus) -> String {
        switch status {
        case .ready: "Ready"
        case .checking: "Checking…"
        case .notInstalled: "Not installed"
        case .signedOut: "Not signed in"
        case .failed: "Can't start"
        }
    }

    private func statusSymbol(_ status: AppModel.EngineStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .checking: "clock"
        default: "exclamationmark.circle"
        }
    }

    private func statusColor(_ status: AppModel.EngineStatus) -> Color {
        switch status {
        case .ready: Theme.color(for: .strong)
        case .checking: Theme.muted
        default: Theme.accent
        }
    }

    private var setupTitle: String {
        let engine = model.engine
        switch model.status(of: engine) {
        case .signedOut: return "\(engine.name) is installed but not signed in"
        case .failed: return "\(engine.name) is installed but couldn't start"
        default: return "\(engine.name)'s command-line tool isn't installed"
        }
    }

    /// What's missing in plain words, the Terminal command that fixes it, and a way out to the other engine.
    private var setupGuide: some View {
        let engine = model.engine
        let status = model.status(of: engine)
        let other = AssessmentEngine.allCases.first { $0 != engine && model.installations[$0] != nil }
        return VStack(alignment: .leading, spacing: 10) {
            switch status {
            case .signedOut:
                guideText("Sign in once in Terminal, then click Check again:")
                TerminalCommand(command: engine.signInCommand)
            case .failed(let message):
                guideText(message)
            default:
                if engine == .claude && engine.hasDesktopApp {
                    guideText("The Claude desktop app is installed, but scoring needs Claude Code's separate `claude` command. Install it in Terminal, then click Check again:")
                } else {
                    guideText("Scoring runs the `\(engine.command)` command. Install it in Terminal, then click Check again:")
                }
                TerminalCommand(command: engine.installCommand)
            }
            HStack(spacing: 14) {
                Link("Setup guide", destination: engine.setupURL)
                if let other {
                    Button("Use \(other.name) instead") { model.engine = other }
                        .buttonStyle(.link)
                }
            }
            .scaledFont(12)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func guideText(_ text: String) -> some View {
        Text(inline(text)).scaledFont(12).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
    }
}

/// A Terminal command in monospace with a Copy button.
private struct TerminalCommand: View {
    var command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            Text(command)
                .scaledFont(12, design: .monospaced)
                .foregroundStyle(Theme.ink)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button(copied ? "Copied" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
            }
            .buttonStyle(AssessmentSecondaryButtonStyle())
            .scaledFont(12)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.rule))
    }
}

/// A real macOS popup fills the column and keeps native menu and keyboard behavior.
private struct ModelPopup: NSViewRepresentable {
    let choices: [String]
    @Binding var selection: String
    let fontSize: CGFloat
    let enabled: Bool
    let identifier: String

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.controlSize = .large
        button.bezelStyle = .rounded
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        button.target = context.coordinator
        button.action = #selector(Coordinator.selectModel(_:))
        button.setAccessibilityLabel("Model")
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.selection = $selection
        if button.itemTitles != choices {
            button.removeAllItems()
            button.addItems(withTitles: choices)
        }
        button.selectItem(withTitle: selection)
        button.font = .systemFont(ofSize: fontSize)
        button.isEnabled = enabled
        button.identifier = NSUserInterfaceItemIdentifier(identifier)
        button.setAccessibilityIdentifier(identifier)
    }

    final class Coordinator: NSObject {
        var selection: Binding<String>
        init(selection: Binding<String>) { self.selection = selection }

        @objc func selectModel(_ sender: NSPopUpButton) {
            guard let title = sender.selectedItem?.title else { return }
            selection.wrappedValue = title
        }
    }
}
