// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import UserNotifications

/// Units, decimals, rest, alerts and theme, and about Kitae. Changes are saved straight away.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    /// Whether alerts are turned off for Kitae in the Settings app, so the rest timer can't
    /// set one off.
    @State private var alertsDenied = false

    static let sourceCode = URL(string: "https://codeberg.org/gureetk/kitae-ios")!

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                LabeledContent("Units") {
                    Picker("Units", selection: $model.settings.unit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.symbol).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .listRowBackground(Color.card)

                LabeledContent("Decimals") {
                    Picker("Decimals", selection: $model.settings.decimals) {
                        ForEach(DecimalStyle.allCases) { style in
                            Text(style.title)
                                .accessibilityLabel(style.spokenName)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                .listRowBackground(Color.card)

                MenuRow(
                    title: "Default rest",
                    selection: $model.settings.defaultRestSeconds,
                    choices: restChoices,
                    name: { $0 > 0 ? restLabel(seconds: $0) : "Off" },
                    spokenName: Self.spokenRest,
                    font: .kitaeMono(15, relativeTo: .body)
                )
                .listRowBackground(Color.card)

                Toggle("Rest timer alerts", isOn: $model.settings.restAlerts)
                    .listRowBackground(Color.card)

                if model.settings.restAlerts, alertsDenied {
                    Button("Allow alerts for Kitae in Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .listRowBackground(Color.card)
                }
            } header: {
                SectionCaption(".workouts")
            } footer: {
                Text("You can type a point or a comma either way. This sets how weights are shown.")
                    .foregroundStyle(.inkSoft)
            }

            Section {
                MenuRow(title: "Theme", selection: $model.settings.theme, choices: AppTheme.allCases, name: \.name)
                    .listRowBackground(Color.card)
            } header: {
                SectionCaption(".appearance")
            }

            Section {
                LabeledContent("Version") {
                    Text(Self.version)
                        .font(.kitaeMono(15, relativeTo: .body))
                        .foregroundStyle(.inkSoft)
                }
                .listRowBackground(Color.card)

                Link(destination: Self.sourceCode) {
                    HStack {
                        Text("Source code")
                            .foregroundStyle(.ink)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.inkFaint)
                    }
                    .contentShape(.rect)
                }
                .accessibilityHint("Opens Kitae's code on Codeberg")
                .listRowBackground(Color.card)
            } header: {
                SectionCaption(".about")
            }
        }
        .listSectionSpacing(20)
        .environment(\.defaultMinListRowHeight, 52)
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle("Settings")
        .task { await checkAlerts() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await checkAlerts() }
            }
        }
    }

    /// Off, and the rest lengths the set and exercise pickers offer.
    private var restChoices: [Int] {
        let choices = [0] + RestSection.choices
        let current = model.settings.defaultRestSeconds
        return choices.contains(current) ? choices : (choices + [current]).sorted()
    }

    /// "1 minute, 30 seconds".
    private nonisolated static func spokenRest(_ seconds: Int) -> String {
        guard seconds > 0 else { return "Off" }
        return Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }

    /// "1.0 (1)": the version, and the build TestFlight counts.
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        guard let build = info?["CFBundleVersion"] as? String else { return version }
        return "\(version) (\(build))"
    }

    private func checkAlerts() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        alertsDenied = settings.authorizationStatus == .denied
    }
}

/// A setting picked from a menu, with its value and ⌃⌄ on the right, like "Default rest 1:30".
private struct MenuRow<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let choices: [Value]
    let name: (Value) -> String
    var spokenName: ((Value) -> String)?
    var font: Font = .body

    var body: some View {
        LabeledContent(title) {
            Menu {
                Picker(title, selection: $selection) {
                    ForEach(choices, id: \.self) { choice in
                        Text(name(choice)).tag(choice)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(name(selection))
                        .font(font)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.inkSoft)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .accessibilityLabel(title)
            .accessibilityValue((spokenName ?? name)(selection))
        }
    }
}
