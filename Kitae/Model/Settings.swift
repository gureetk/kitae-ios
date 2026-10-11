// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Light or dark whatever the phone uses, or the same as the phone.
nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: Self { self }

    var name: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

/// What Settings changes.
nonisolated struct AppSettings: Equatable, Sendable {
    var unit: WeightUnit = .kilograms
    var decimals: DecimalStyle = .automatic
    /// The rest after a set when neither the set nor its exercise has one of its own, like
    /// Kitae for Android's rest timer setting. 0 starts no rest.
    var defaultRestSeconds = 90
    /// Whether "Rest over" goes off when a rest runs out.
    var restAlerts = true
    var theme: AppTheme = .system
}

/// Keeps Settings on the phone, in UserDefaults. The settings Kitae for Android also has are
/// stored under its names and values (`weight_unit` is `Kilograms` or `Pounds`, and so on),
/// ready for backups.
final class SettingsStore {
    enum Key {
        static let unit = "weight_unit"
        static let decimals = "decimals"
        static let defaultRest = "rest_timer_seconds"
        static let restAlerts = "rest_alerts"
        static let theme = "theme"
    }

    private static let unitNames: [WeightUnit: String] = [.kilograms: "Kilograms", .pounds: "Pounds"]
    private static let themeNames: [AppTheme: String] = [.system: "System", .light: "Light", .dark: "Dark"]

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    static var standard: SettingsStore { SettingsStore(defaults: .standard) }

    /// Keeps nothing, for tests and example data.
    static var none: SettingsStore { SettingsStore(defaults: nil) }

    /// The saved settings. Anything missing or unreadable is left as it comes.
    func load() -> AppSettings {
        var settings = AppSettings()
        guard let defaults else { return settings }
        if let name = defaults.string(forKey: Key.unit),
           let unit = Self.unitNames.first(where: { $0.value == name })?.key {
            settings.unit = unit
        }
        if let name = defaults.string(forKey: Key.decimals), let decimals = DecimalStyle(rawValue: name) {
            settings.decimals = decimals
        }
        if let seconds = defaults.object(forKey: Key.defaultRest) as? Int, seconds >= 0 {
            settings.defaultRestSeconds = seconds
        }
        if let isOn = defaults.object(forKey: Key.restAlerts) as? Bool {
            settings.restAlerts = isOn
        }
        if let name = defaults.string(forKey: Key.theme),
           let theme = Self.themeNames.first(where: { $0.value == name })?.key {
            settings.theme = theme
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let defaults else { return }
        defaults.set(Self.unitNames[settings.unit], forKey: Key.unit)
        defaults.set(settings.decimals.rawValue, forKey: Key.decimals)
        defaults.set(settings.defaultRestSeconds, forKey: Key.defaultRest)
        defaults.set(settings.restAlerts, forKey: Key.restAlerts)
        defaults.set(Self.themeNames[settings.theme], forKey: Key.theme)
    }
}

/// A rest as the rest pickers name it: "1:30", or "off" when there's none.
nonisolated func restSetting(seconds: Int) -> String {
    seconds > 0 ? restLabel(seconds: seconds) : "off"
}
