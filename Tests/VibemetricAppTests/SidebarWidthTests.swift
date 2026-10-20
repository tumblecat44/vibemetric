import AppKit
import SwiftUI
import Testing
@testable import VibemetricAppKit

/// The main window's sidebar: it keeps its width while the window shrinks, never goes below its minimum,
/// and can be dragged wider than before.
@Suite(.serialized)
@MainActor
struct SidebarWidthTests {
    private func makeWindow(width: CGFloat) throws -> (NSWindow, UserDefaults, String) {
        let name = "sidebar-tests-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: name))
        preferences.set(false, forKey: AutoSettings.enabledKey)
        let model = AppModel(preferences: preferences, startAutomatically: false, history: [])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: 700),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        // A hosting controller, as the app's Window scene uses: NavigationSplitView applies its column widths
        // through the split view controller it creates there.
        window.contentViewController = NSHostingController(rootView: RootView().environment(model)
            .frame(minHeight: 640))
        window.setContentSize(NSSize(width: width, height: 700))
        return (window, preferences, name)
    }

    private func settle(_ window: NSWindow) async {
        for _ in 0..<6 {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private func splitView(in view: NSView) -> NSSplitView? {
        if let split = view as? NSSplitView { return split }
        return view.subviews.lazy.compactMap(splitView).first
    }

    private func sidebarWidth(_ window: NSWindow) throws -> CGFloat {
        let content = try #require(window.contentView)
        let split = try #require(splitView(in: content), "NavigationSplitView renders as an NSSplitView")
        return try #require(split.arrangedSubviews.first).frame.width
    }

    private func resize(_ window: NSWindow, to width: CGFloat) async {
        window.setContentSize(NSSize(width: width, height: 700))
        await settle(window)
    }

    /// Dragging the window's edge in can't go below its minimum, which is the sidebar's current width plus the
    /// detail column's minimum, so the sidebar keeps its width all the way down.
    @Test func windowMinimumFollowsTheSidebar() async throws {
        let (window, preferences, name) = try makeWindow(width: 1300)
        defer { window.close(); preferences.removePersistentDomain(forName: name) }
        await settle(window)
        let start = try sidebarWidth(window)
        // At least the sidebar plus the detail minimum; macOS versions add a few points for the divider and insets.
        let minimum = window.contentMinSize.width
        #expect(minimum >= start + RootView.detailMinWidth - 1 && minimum <= start + RootView.detailMinWidth + 16)
        await resize(window, to: window.contentMinSize.width)
        let atMinimum = try sidebarWidth(window)
        #expect(abs(atMinimum - start) < 1, "At the window's minimum the sidebar still has its width")

        await resize(window, to: 1300)
        let content = try #require(window.contentView)
        let split = try #require(splitView(in: content))
        split.setPosition(400, ofDividerAt: 0)
        await settle(window)
        let widened = try sidebarWidth(window)
        let widenedMinimum = window.contentMinSize.width
        #expect(widenedMinimum >= widened + RootView.detailMinWidth - 1 && widenedMinimum <= widened + RootView.detailMinWidth + 16,
                "A wider sidebar raises the window's minimum")
        await resize(window, to: window.contentMinSize.width)
        let widenedAtMinimum = try sidebarWidth(window)
        #expect(abs(widenedAtMinimum - widened) < 1)
    }

    @Test func sidebarKeepsItsWidthWhenTheWindowShrinks() async throws {
        let (window, preferences, name) = try makeWindow(width: 1300)
        defer { window.close(); preferences.removePersistentDomain(forName: name) }
        await settle(window)
        let wide = try sidebarWidth(window)
        #expect(wide >= RootView.sidebarMinWidth)

        await resize(window, to: 1000)
        let afterShrink = try sidebarWidth(window)
        #expect(abs(afterShrink - wide) < 1, "Shrinking the window shrinks the detail column, not the sidebar")

        // Below the window's minimum, AppKit keeps the window at its minimum; the sidebar still holds its width.
        await resize(window, to: 600)
        let atMinimum = try sidebarWidth(window)
        #expect(atMinimum >= RootView.sidebarMinWidth - 0.5)
    }

    @Test func sidebarCanBeDraggedWiderThanBefore() async throws {
        let (window, preferences, name) = try makeWindow(width: 1400)
        defer { window.close(); preferences.removePersistentDomain(forName: name) }
        await settle(window)
        let content = try #require(window.contentView)
        let split = try #require(splitView(in: content))
        split.setPosition(480, ofDividerAt: 0)
        await settle(window)
        let dragged = try sidebarWidth(window)
        #expect(dragged > 400, "The old maximum was AppKit's default, well under 400")
        split.setPosition(100, ofDividerAt: 0)
        await settle(window)
        let narrowest = try sidebarWidth(window)
        #expect(narrowest >= RootView.sidebarMinWidth - 0.5)
    }
}
