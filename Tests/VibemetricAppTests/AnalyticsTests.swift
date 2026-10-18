import Foundation
import Testing
@testable import VibemetricAppKit

/// Usage counts: nothing without a project key, nothing after opting out, and only the documented fields.
@Suite(.serialized)
@MainActor
struct AnalyticsTests {
    /// What the client would have posted, in order.
    final class Sent {
        var events: [[String: Any]] = []
        var names: [String] { events.compactMap { $0["event"] as? String } }
    }

    private func withAnalytics(key: String?, _ body: (Sent) throws -> Void) throws {
        let name = "analytics-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        let (oldKey, oldDefaults, oldSend) = (Analytics.projectKey, Analytics.defaults, Analytics.send)
        let sent = Sent()
        Analytics.projectKey = key
        Analytics.defaults = defaults
        Analytics.send = { request in
            if let body = request.httpBody, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                sent.events.append(json)
            }
        }
        defer {
            (Analytics.projectKey, Analytics.defaults, Analytics.send) = (oldKey, oldDefaults, oldSend)
            defaults.removePersistentDomain(forName: name)
        }
        try body(sent)
    }

    @Test func buildWithoutKeySendsNothing() throws {
        try withAnalytics(key: nil) { sent in
            Analytics.start()
            Analytics.capture("assessment_started")
            #expect(!Analytics.isAvailable)
            #expect(sent.events.isEmpty)
        }
    }

    @Test func firstLaunchCountsAnInstallOnce() throws {
        try withAnalytics(key: "phc_test") { sent in
            Analytics.start()
            #expect(sent.names == ["app_installed", "app_launched", "app_active"])
            sent.events.removeAll()
            Analytics.start()
            #expect(sent.names == ["app_launched"], "Same day, already installed")
            let ids = Set(sent.events.compactMap { $0["distinct_id"] as? String })
            #expect(ids.count == 1)
        }
    }

    @Test func activeDayIsSentOncePerDay() throws {
        try withAnalytics(key: "phc_test") { sent in
            let day = Date(timeIntervalSince1970: 1_800_000_000)
            Analytics.markActiveDay(now: day)
            Analytics.markActiveDay(now: day.addingTimeInterval(60))
            Analytics.markActiveDay(now: day.addingTimeInterval(86_400))
            #expect(sent.events.count == 2)
        }
    }

    @Test func optingOutStopsEventsAndForgetsTheID() throws {
        try withAnalytics(key: "phc_test") { sent in
            Analytics.start()
            let id = try #require(sent.events.first?["distinct_id"] as? String)
            sent.events.removeAll()
            Analytics.isEnabled = false
            Analytics.capture("assessment_started")
            #expect(sent.names == ["analytics_disabled"])
            #expect(Analytics.defaults.string(forKey: Analytics.installIDKey) == nil)
            Analytics.isEnabled = true
            #expect(sent.events.last?["distinct_id"] as? String != id, "Opting back in starts a new ID")
        }
    }

    @Test func eventsAreAnonymous() throws {
        try withAnalytics(key: "phc_test") { sent in
            Analytics.capture("assessment_completed", ["engine": "claude"])
            let event = try #require(sent.events.first)
            #expect(event["api_key"] as? String == "phc_test")
            let props = try #require(event["properties"] as? [String: Any])
            #expect(props["engine"] as? String == "claude")
            #expect(props["$process_person_profile"] as? Bool == false)
            #expect(props["$geoip_disable"] as? Bool == true)
        }
    }
}
