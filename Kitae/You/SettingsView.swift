// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

/// Units, decimals, rest, alerts and theme, backups, starting over, and about Kitae. Changes
/// are saved straight away.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    /// Whether alerts are turned off for Kitae in the Settings app, so the rest timer can't
    /// set one off.
    @State private var alertsDenied = false
    @State private var isImporting = false
    @State private var importing = ImportKind.backup
    /// Restoring a backup or resetting, waiting for an answer.
    @State private var confirmation: Confirmation?
    @State private var activity: BackupActivity?
    @State private var notice: Notice?

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

            backupSection

            Section {
                Button("Reset Kitae", role: .destructive) {
                    confirmation = .reset
                }
                .disabled(model.backups.isWorking)
                .listRowBackground(Color.card)
            } header: {
                SectionCaption(".reset")
            } footer: {
                Text("Deletes all plans, workouts, exercises and settings, like a fresh install. Backups are kept.")
                    .foregroundStyle(.inkSoft)
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
        .fileImporter(isPresented: $isImporting, allowedContentTypes: importing.contentTypes) { result in
            picked(result)
        }
        .confirmationDialog(
            confirmation?.title ?? "",
            isPresented: Binding(get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
            titleVisibility: .visible,
            presenting: confirmation
        ) { question in
            Button(question.action, role: .destructive) {
                confirmed(question)
            }
        } message: { question in
            Text(question.message)
        }
        .alert(
            notice?.title ?? "",
            isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } }),
            presenting: notice
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
        .sensoryFeedback(.success, trigger: model.backups.lastBackup)
        .task { await checkAlerts() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await checkAlerts() }
            }
        }
    }

    // MARK: Backups

    private var backupSection: some View {
        @Bindable var model = model
        return Section {
            Toggle("Back up after each workout", isOn: $model.settings.backUpAfterWorkouts)
                .listRowBackground(Color.card)

            Button {
                importing = .folder
                isImporting = true
            } label: {
                HStack(spacing: 8) {
                    Text("Backup folder")
                        .foregroundStyle(.ink)
                    Spacer(minLength: 8)
                    Text(model.backups.folderName)
                        .foregroundStyle(.inkSoft)
                        .lineLimit(1)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.inkFaint)
                }
                .contentShape(.rect)
            }
            .disabled(model.backups.isWorking)
            .accessibilityLabel("Backup folder")
            .accessibilityValue(model.backups.folderName)
            .accessibilityHint("Chooses where backups are saved")
            .listRowBackground(Color.card)

            actionRow("Back up now", isRunning: activity == .backingUp) {
                Task { await backUpNow() }
            }
            actionRow("Restore from a backup", isRunning: activity == .restoring) {
                chooseBackup()
            }
        } header: {
            SectionCaption(".backups")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let problem = model.backups.problem {
                    Text("The last backup didn't work. \(problem)")
                        .foregroundStyle(.red)
                }
                Text(backupSummary)
                    .foregroundStyle(.inkSoft)
            }
        }
    }

    private func actionRow(_ title: String, isRunning: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                if isRunning {
                    ProgressView()
                }
            }
            .contentShape(.rect)
        }
        .disabled(model.backups.isWorking)
        .listRowBackground(Color.card)
    }

    /// "Last backup: today at 6:31 PM. Kitae on Android can restore these backups too."
    private var backupSummary: String {
        let android = "Kitae on Android can restore these backups too."
        guard let last = model.backups.lastBackup else { return "No backups yet. \(android)" }
        let format = DateFormatter()
        format.dateStyle = .medium
        format.timeStyle = .short
        format.doesRelativeDateFormatting = true
        format.formattingContext = .middleOfSentence
        return "Last backup: \(format.string(from: last)). \(android)"
    }

    private func backUpNow() async {
        activity = .backingUp
        defer { activity = nil }
        guard !(await model.backUp()), let problem = model.backups.problem else { return }
        notice = Notice(title: "Couldn't back up", message: problem)
    }

    private func chooseBackup() {
        guard model.workout == nil else {
            notice = Notice(title: "Can't restore a backup now", message: BackupError.workoutInProgress.localizedDescription)
            return
        }
        importing = .backup
        isImporting = true
    }

    private func picked(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            switch importing {
            case .folder:
                do {
                    try model.backups.choose(url)
                } catch {
                    notice = Notice(title: "Couldn't use that folder", message: error.localizedDescription)
                }
            case .backup:
                // Asked once Files has gone, as a question asked while it's leaving doesn't show.
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    confirmation = .restore(url)
                }
            }
        case .failure(let error):
            notice = Notice(title: "Couldn't open that", message: error.localizedDescription)
        }
    }

    private func confirmed(_ confirmation: Confirmation) {
        switch confirmation {
        case .restore(let url):
            Task { await restore(url) }
        case .reset:
            // Once the question has gone, as every screen is made again.
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                reset()
            }
        }
    }

    private func restore(_ url: URL) async {
        activity = .restoring
        defer { activity = nil }
        do {
            try await model.restoreBackup(from: url)
            notice = Notice(title: "Backup restored", message: "Kitae now has the plans, workouts and exercises from \(url.lastPathComponent).")
        } catch {
            notice = Notice(title: "Couldn't restore the backup", message: error.localizedDescription)
        }
    }

    /// Starts over. Kitae's screens are made again, so this one goes away.
    private func reset() {
        do {
            try model.reset()
        } catch {
            notice = Notice(title: "Couldn't reset Kitae", message: error.localizedDescription)
        }
    }

    // MARK: Workouts and about

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

/// What Files is picking: a folder for backups, or a backup to restore.
private enum ImportKind {
    case folder
    case backup

    var contentTypes: [UTType] {
        switch self {
        case .folder: [.folder]
        // A backup saved by some Android apps has no .zip at the end of its name.
        case .backup: [.zip, .data]
        }
    }
}

private enum BackupActivity {
    case backingUp
    case restoring
}

/// A question asked before something that can't be undone.
private enum Confirmation {
    /// Restoring the backup picked in Files.
    case restore(URL)
    case reset

    var title: String {
        switch self {
        case .restore: "Restore this backup?"
        case .reset: "Reset Kitae?"
        }
    }

    var action: String {
        switch self {
        case .restore: "Restore"
        case .reset: "Reset"
        }
    }

    var message: String {
        switch self {
        case .restore(let url):
            "Your plans, workouts, exercises and settings will be replaced by the ones in \(url.lastPathComponent). What's in Kitae now is saved first, as \(Backups.beforeRestoreName) in On My iPhone › Kitae."
        case .reset:
            "This permanently deletes all your plans, workouts, exercises and settings, and Kitae starts again with its starter plan and exercises. Backups in your backup folder are kept."
        }
    }
}

/// An alert after backing up or restoring.
private struct Notice {
    let title: String
    let message: String
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
