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
                        Text(String(format: "Scoring… %d:%02d", s / 60, s % 60))
                            .scaledFont(12, design: .monospaced)
                    }
                }
            }

            if let next = AutoSchedule(enabled: autoEnabled, minuteOfDay: autoMinute).next(after: Date()) {
                Text("Next automatic score: \(RelativeDate.format(next))")
                    .scaledFont(11)
                    .foregroundStyle(.secondary)
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
            VStack(alignment: .leading, spacing: 10) {
                if let count = imp.count, let label = imp.countLabel, !label.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(count)").scaledFont(28, weight: .bold).monospacedDigit()
                        Text(inline(label)).scaledFont(14, weight: .medium).fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    (Text("Fix: ").bold() + Text(inline(imp.title)))
                        .scaledFont(13)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Cards without a count: the fix itself is the headline.
                    Text(inline(imp.title)).scaledFont(15, weight: .semibold).fixedSize(horizontal: false, vertical: true)
                    if let target = imp.dimension {
                        Text(target.title).scaledFont(12).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

            if card.moreToFix > 0 {
                HStack {
                    Spacer()
                    Button("+\(card.moreToFix) more to fix →") { show(selectLatest: true) }
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

    private func show(selectLatest: Bool) {
        close()
        model.showMainWindow(selectLatest: selectLatest)
    }
}
