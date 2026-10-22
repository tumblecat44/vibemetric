import SwiftUI
import VibemetricCore

/// The app's one main window (the `Window` scene with id "main").
@MainActor
enum MainWindow {
    /// The main window, while it's on screen.
    static var visible: NSWindow? {
        NSApp.windows.first { $0.isVisible && $0.identifier?.rawValue.contains("main") == true }
    }

    static func close() { visible?.performClose(nil) }
}

/// Keeps Vibemetric running in the menu bar after its window is closed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Clicking the Dock icon, or opening the app again, brings the main window back.
    /// `hasVisibleWindows` counts helper windows (status item, popover), so check the main window itself.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated {
            if MainWindow.visible == nil { AppModel.shared?.showMainWindow(selectLatest: false) }
        }
        return true
    }
}

/// The app itself. The `VibemetricApp` executable is a tiny launcher that calls `VibemetricMain.main()`,
/// so other modules can import everything here.
public struct VibemetricMain: App {
    /// Runs once at launch, after the app model exists and before any window. The launcher uses it to
    /// register optional modules into `Extensions`.
    @MainActor public static var beforeLaunch: (@MainActor (AppModel) -> Void)?

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model: AppModel
    @AppStorage(TextScale.storageKey) private var textScale = 1.0
    private let statusItem: StatusItemController

    public init() {
        MainActor.assumeIsolated {
            Snapshot.runIfRequested()
            Snapshot.notificationTestIfRequested()
        }
        // Lets `swift run VibemetricApp` show a normal window without an .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        AppVariant.migrateLegacySettings()
        TextScaleCommands.installEqualsShortcut()
        LaunchAtLogin.enableOnFirstLaunch()
        MainActor.assumeIsolated { Notifier.shared.install() }
        // Before the updater starts, so its first check can't be mistaken for an earlier version's.
        MainActor.assumeIsolated { Analytics.start() }
        _ = MainActor.assumeIsolated { AppUpdater.shared }
        let model = MainActor.assumeIsolated { AppModel() }
        MainActor.assumeIsolated {
            AppModel.shared = model
            Self.beforeLaunch?(model)
        }
        _model = State(initialValue: model)
        statusItem = MainActor.assumeIsolated { StatusItemController(model: model) }
    }

    public var body: some Scene {
        Window("Vibemetric", id: "main") {
            RootView()
                .environment(model)
                .environment(\.textScale, textScale)
                // Width comes from RootView, which follows the sidebar; an outer minWidth here would override it.
                .frame(minHeight: 640)
        }
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(after: .appInfo) {
                if AppUpdater.shared.isEnabled {
                    Button("Check for Updates…") { AppUpdater.shared.checkForUpdates() }
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Assessment") { model.selected = nil; model.showsSettings = false }
                    .keyboardShortcut("n")
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.showSettings() }
                    .keyboardShortcut(",")
            }
            // ⌘W closes the main window, even while the menu bar panel is the active window; the panel stays open
            // until it's dismissed (a click elsewhere, Esc, or the menu bar item).
            CommandGroup(replacing: .saveItem) {
                Button("Close Window") { MainWindow.close() }
                    .keyboardShortcut("w")
            }
            TextScaleCommands()
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    /// Always both columns: the sidebar is never folded away, even when the window gets narrow.
    @State private var columns = NavigationSplitViewVisibility.all
    /// The sidebar's current width. The window's minimum is this plus the detail column's minimum, so dragging
    /// the window's edge in stops before it would take space from the sidebar.
    @State private var sidebarWidth = RootView.sidebarIdealWidth

    /// Sidebar widths: it never gets narrower than the minimum, and people can drag it out to the maximum.
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 260
    static let sidebarMaxWidth: CGFloat = 520
    /// The detail column absorbs window resizing down to this width; the window's minimum is both minimums added,
    /// so shrinking the window never squeezes the sidebar.
    static let detailMinWidth: CGFloat = 640
    /// Some macOS versions report the sidebar's content 8 points narrower than its column (CI's runner does), so the
    /// window's minimum allows for that much column chrome rather than squeeze the sidebar by it.
    static let sidebarChromeAllowance: CGFloat = 8

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columns) {
            VStack(spacing: 0) {
                if !Extensions.sidebarTabs.isEmpty {
                    Picker("View", selection: $model.sidebarTab) {
                        Text(AppModel.generalTab).tag(AppModel.generalTab)
                        ForEach(Extensions.sidebarTabs) { Text($0.id).tag($0.id) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .onChange(of: model.sidebarTab) { _, _ in model.showsSettings = false }
                }

                if let tab = Extensions.sidebarTabs.first(where: { $0.id == model.sidebarTab }) {
                    tab.sidebar()
                } else {
                    generalList
                }
            }
            // Settings pinned to the bottom of the sidebar, below the scrolling history.
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    Button { model.showSettings() } label: {
                        Label("Settings", systemImage: "gearshape")
                            .scaledFont(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.showsSettings ? Color.primary : Color.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .help("Settings (⌘,)")
                }
                // Opaque, so result rows scrolling underneath don't show through the button.
                .background(.bar)
            }
            // The toggle would fold the sidebar away; remove it before setting the widths, because a toolbar modifier
            // applied after `navigationSplitViewColumnWidth` hides the widths from the split view.
            .toolbar(removing: .sidebarToggle)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { sidebarWidth = $0 }
            .navigationSplitViewColumnWidth(min: Self.sidebarMinWidth, ideal: Self.sidebarIdealWidth, max: Self.sidebarMaxWidth)
        } detail: {
            ZStack {
                Theme.paper.ignoresSafeArea()
                if model.showsSettings {
                    SettingsView()
                } else if let tab = Extensions.sidebarTabs.first(where: { $0.id == model.sidebarTab }) {
                    tab.detail()
                } else if let record = model.selected {
                    CardView(record: record)
                } else if model.isRunning && model.showsRunProgress {
                    RunningView()
                } else {
                    HomeView()
                }
            }
            // A small ideal width, so the split view lets the detail shrink to its minimum before anything else.
            .frame(minWidth: Self.detailMinWidth, idealWidth: Self.detailMinWidth, maxWidth: .infinity)
            .navigationSplitViewColumnWidth(min: Self.detailMinWidth, ideal: 860)
        }
        .frame(minWidth: max(sidebarWidth, Self.sidebarMinWidth) + Self.sidebarChromeAllowance + Self.detailMinWidth)
        .onChange(of: columns) { _, visibility in
            if visibility != .all { columns = .all }
        }
        // Lets the menu bar item (AppKit) reopen this window after it's been closed.
        .onAppear { model.openMainWindow = { openWindow(id: "main") } }
    }
}

extension RootView {
    /// The score history: new assessment, the run in progress, past results.
    var generalList: some View {
        @Bindable var model = model
        return List(selection: $model.selected) {
            Section(model.history.isEmpty ? "" : "Past results") {
                // "Run my score" sits above the newest result, the same size as a result row.
                // While a run is going, the in-progress row takes its place.
                if !model.isRunning {
                    Button {
                        // Opens the start screen: engine and model options, then "Start assessment".
                        model.showsSettings = false
                        model.selected = nil
                        model.showsRunProgress = false
                    } label: { RunMyScoreRow() }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        model.selected == nil && !model.showsSettings
                            ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.25)).padding(.horizontal, 10)
                            : nil
                    )
                    .help("Choose the engine and model, then start a score")
                }
                if !model.history.isEmpty || model.isRunning {
                    // The run in progress sits on top; it becomes the newest result when done.
                    if model.isRunning {
                        Button { model.selected = nil; model.showsSettings = false; model.showsRunProgress = true } label: { InProgressRow() }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                model.selected == nil && !model.showsSettings
                                    ? RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.25)).padding(.horizontal, 10)
                                    : nil
                            )
                            .help("Show progress")
                    }
                    ForEach(model.history) { record in
                        HistoryRow(record: record).tag(record)
                            .contextMenu {
                                Button("Delete", role: .destructive) { model.delete(record) }
                            }
                    }
                }
            }
        }
    }
}

/// Sidebar row for the assessment that's running now: spinner in the score circle, elapsed time.
struct InProgressRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.textScale) private var scale

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.muted.opacity(0.35))
                ProgressView().controlSize(.small)
            }
            .frame(width: 34 * scale, height: 34 * scale)
            VStack(alignment: .leading, spacing: 1) {
                Text("Scoring…").scaledFont(13, weight: .semibold)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let s = Int(ctx.date.timeIntervalSince(model.runStarted ?? ctx.date))
                    Text(String(format: "%d%% · %d:%02d elapsed", model.progress.percent(at: ctx.date), s / 60, s % 60))
                        .scaledFont(10, design: .monospaced)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The sidebar call to action, shaped like a result row: an accent circle with a plus, then two lines.
struct RunMyScoreRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.textScale) private var scale

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent)
                Image(systemName: "plus")
                    .font(.system(size: 15 * scale, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34 * scale, height: 34 * scale)
            VStack(alignment: .leading, spacing: 1) {
                Text("Run my score").scaledFont(13, weight: .semibold).foregroundStyle(Theme.accent)
                Text(subtitle).scaledFont(10).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var subtitle: String {
        if model.installations[model.engine] == nil { return "Set up \(model.engine.name) first" }
        if let reason = Extensions.currentBusyReason { return reason }
        return "\(model.engine.name) · about 5 minutes"
    }
}

struct HistoryRow: View {
    var record: CardRecord

    var body: some View {
        HStack(spacing: 10) {
            ScoreBadge(card: record.card)
            VStack(alignment: .leading, spacing: 1) {
                RelativeDateText(date: record.createdAt)
                Text("\(record.engineLabel) · \(record.sessionsScanned) sessions\(record.automatic == true ? " · auto" : "")")
                    .scaledFont(10).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
