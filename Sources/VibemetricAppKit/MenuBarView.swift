import AppKit
import SwiftUI
import VibemetricCore

/// Draws the menu bar item: gauge icon plus the latest score (or "Scoring…").
enum MenuBarLabel {
    static func statusImage(symbol: String, text: String) -> NSImage {
        let height: CGFloat = 18
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) ?? NSImage()
        let label = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.black,
        ])
        let gap: CGFloat = text.isEmpty ? 0 : 4
        let size = NSSize(width: ceil(icon.size.width + gap + label.size().width), height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            icon.draw(in: NSRect(x: 0, y: (height - icon.size.height) / 2, width: icon.size.width, height: icon.size.height))
            label.draw(at: NSPoint(x: icon.size.width + gap, y: (height - label.size().height) / 2))
            return true
        }
        // Template images take the menu bar's own color in light, dark, and tinted menu bars.
        image.isTemplate = true
        return image
    }
}

/// The panel that drops down from the menu bar item.
/// Left-click shows this; right-click shows the StatusItemController menu (copy, settings, quit).
struct MenuBarPanel: View {
    @Environment(AppModel.self) private var model
    // Read so the "Next automatic score" line refreshes as soon as Settings change.
    @AppStorage(AutoSettings.enabledKey) private var autoEnabled = true
    @AppStorage(AutoSettings.minuteKey) private var autoMinute = AutoSchedule.defaultMinuteOfDay
    @AppStorage(AutoSettings.daysKey) private var autoDays = AutoSchedule.everyDay
    @Environment(\.textScale) private var scale
    /// Closes the popover before an action opens another window.
    var close: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let latest = model.history.first {
                summary(latest)
            } else {
                Text("No score yet")
                    .scaledFont(18, weight: .bold, design: .serif)
                Text("Run your first assessment to see how you work with AI.")
                    .scaledFont(12).foregroundStyle(.secondary)
            }

            if model.isRunning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let s = Int(ctx.date.timeIntervalSince(model.runStarted ?? ctx.date))
                        Text(String(format: "Scoring… %d%% · %d:%02d", model.progress.percent(at: ctx.date), s / 60, s % 60))
                            .scaledFont(12, design: .monospaced)
                    }
                }
            }

            if let next = AutoSchedule(enabled: autoEnabled, minuteOfDay: autoMinute, days: autoDays).next(after: Date()) {
                Text("Next automatic score: \(RelativeDate.formatUpcoming(next))")
                    .scaledFont(11)
                    .foregroundStyle(.secondary)
            }

            if !model.isRunning, let problem = model.engineProblem {
                Label("\(problem). Open Vibemetric to set it up.", systemImage: "exclamationmark.circle")
                    .scaledFont(11)
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Open Vibemetric") { show(selectLatest: true) }
                Spacer()
                Button(model.isRunning ? "Running…" : "Score me again") {
                    model.startAssessment()
                    show(selectLatest: false)
                }
                .disabled(!model.canStartAssessment)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(16)
        .frame(width: 340 * scale)
    }

    /// The most urgent fix leads; the score is a small line under it, so the number doesn't come first.
    private func summary(_ record: CardRecord) -> some View {
        let card = record.card
        let imp = card.improvement
        return VStack(alignment: .leading, spacing: 10) {
            Text("Most urgent").scaledFont(12, weight: .semibold).foregroundStyle(.secondary)
            // Two problems, each with its fix: the card's first improvement, then the weakest other category.
            fixBox(number: 1, problem: imp.situation, fix: imp.title, category: imp.dimension?.title)
            let second = card.nextFixes.first { $0.isReadable && $0.tryThis?.isEmpty == false }
            if let second {
                fixBox(number: 2, problem: second.saw ?? second.headline, fix: second.tryThis ?? "", category: second.dimension.title)
            }
            let rest = card.moreToFix - (second == nil ? 0 : 1)
            if rest > 0 {
                HStack {
                    Spacer()
                    Button("+\(rest) more to fix →") { show(selectLatest: true) }
                        .buttonStyle(.plain)
                        .scaledFont(12, weight: .medium)
                        .foregroundStyle(Theme.accent)
                }
            }

            Divider()
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Score").scaledFont(12).foregroundStyle(.secondary)
                Text(card.totalLabel ?? "—").scaledFont(17, weight: .semibold).monospacedDigit()
                Text("/ 100").scaledFont(12, design: .monospaced).foregroundStyle(.secondary)
                if let baseline = model.baseline(for: record), let delta = ScoreChanges.totalDelta(card, to: baseline.card), delta != 0 {
                    Text("\(delta > 0 ? "↗ +" : "↘ ")\(delta)")
                        .scaledFont(12, weight: .semibold)
                        .foregroundStyle(delta > 0 ? Theme.color(for: .strong) : Theme.color(for: .bottleneck))
                        .help("Since \(baseline.createdAt.formatted(date: .abbreviated, time: .shortened))")
                }
                Spacer()
                RelativeDateText(date: record.createdAt).scaledFont(11).foregroundStyle(.secondary)
            }
        }
    }

    /// One problem and its fix, labeled so the two are never confused.
    private func fixBox(number: Int, problem: String, fix: String, category: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .scaledFont(12, weight: .bold)
                .frame(width: 20, height: 20)
                .background(Theme.accent.opacity(0.18), in: Circle())
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 8) {
                (Text("Problem: ").bold() + Text(inline(problem)))
                    .scaledFont(13)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                // A line between the problem and the fix; Divider() is too faint on the grey box.
                Rectangle().fill(.secondary.opacity(0.4)).frame(height: 1)
                (Text("Fix: ").bold().foregroundColor(Theme.accent) + Text(inline(fix)))
                    .scaledFont(13)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let category { Text(category).scaledFont(11).foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private func show(selectLatest: Bool) {
        close()
        model.showMainWindow(selectLatest: selectLatest)
    }
}
