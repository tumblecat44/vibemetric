import Foundation

/// Anonymous usage counts sent to PostHog: that the app was installed and opened, and how assessments went.
/// Only official release builds have a project key (`scripts/build-app.sh` adds `VMPostHogKey`), so builds from
/// source, dev builds and `swift run` never send anything. People turn it off in Settings → General.
///
/// Events carry a random install ID and the properties named at each call, never transcripts, prompts,
/// file paths, project names, notes or error messages.
@MainActor
public enum Analytics {
    public static let enabledKey = "analyticsEnabled"
    static let installIDKey = "analyticsInstallID"
    static let lastActiveDayKey = "analyticsLastActiveDay"

    /// The public `phc_` project key, present only in official builds.
    static var projectKey = Bundle.main.object(forInfoDictionaryKey: "VMPostHogKey") as? String
    /// Goes through the website's /ingest proxy (vibemetric-web `next.config.ts`) to PostHog.
    static let host = Bundle.main.object(forInfoDictionaryKey: "VMPostHogHost") as? String ?? "https://vibemetric.app/ingest"

    static var defaults = UserDefaults.standard
    /// Replaced in tests to see what would be sent.
    static var send: (URLRequest) -> Void = { URLSession.shared.dataTask(with: $0).resume() }

    /// True in a build that can send usage counts, whether or not the person has turned them off.
    public static var isAvailable: Bool { !(projectKey ?? "").isEmpty }

    public static var isEnabled: Bool {
        get { isAvailable && (defaults.object(forKey: enabledKey) as? Bool ?? true) }
        set {
            guard newValue != isEnabled else { return }
            if newValue {
                defaults.set(true, forKey: enabledKey)
                capture("analytics_enabled")
            } else {
                capture("analytics_disabled")
                defaults.set(false, forKey: enabledKey)
                // Turning it back on later starts as a new, unrelated install.
                defaults.removeObject(forKey: installIDKey)
                defaults.removeObject(forKey: lastActiveDayKey)
            }
        }
    }

    /// Call once at launch. The first launch with analytics sends `app_installed`; every launch sends
    /// `app_launched`, and the first one each day `app_active`.
    static func start() {
        guard isEnabled else { return }
        if defaults.string(forKey: installIDKey) == nil {
            // Sparkle records its first update check, so an existing check means an update from a version
            // without analytics rather than a new install.
            let updated = defaults.object(forKey: "SULastCheckTime") != nil
            _ = installID
            capture("app_installed", ["updated_from_older_version": updated])
        }
        capture("app_launched")
        markActiveDay()
    }

    /// Sends `app_active` the first time it's called on each calendar day. The app stays open in the menu bar
    /// for days, so this is called again from the minute timer.
    static func markActiveDay(now: Date = Date()) {
        guard isEnabled else { return }
        let day = dayFormatter.string(from: now)
        guard defaults.string(forKey: lastActiveDayKey) != day else { return }
        defaults.set(day, forKey: lastActiveDayKey)
        capture("app_active")
    }

    /// Sends one event. Property values must be numbers, booleans or short fixed strings, never user content.
    public static func capture(_ event: String, _ properties: [String: Any] = [:]) {
        guard isEnabled, let projectKey, let url = URL(string: host + "/i/v0/e/") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload(event, properties, key: projectKey))
        send(request)
    }

    static func payload(_ event: String, _ properties: [String: Any], key: String, now: Date = Date()) -> [String: Any] {
        let info = Bundle.main.infoDictionary ?? [:]
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var props: [String: Any] = [
            "app_version": info["CFBundleShortVersionString"] as? String ?? "dev",
            "app_build": info["CFBundleVersion"] as? String ?? "dev",
            "os_version": "\(os.majorVersion).\(os.minorVersion)",
            "arch": architecture,
            "pro_enabled": AppVariant.proEnabled,
            // Anonymous events: no person profiles, no location from the IP address.
            "$process_person_profile": false,
            "$geoip_disable": true,
            "$lib": "vibemetric-macos",
        ]
        props.merge(properties) { _, new in new }
        return ["api_key": key, "event": event, "distinct_id": installID, "properties": props,
                "timestamp": ISO8601DateFormatter().string(from: now)]
    }

    static var installID: String {
        if let id = defaults.string(forKey: installIDKey) { return id }
        let id = UUID().uuidString.lowercased()
        defaults.set(id, forKey: installIDKey)
        return id
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
