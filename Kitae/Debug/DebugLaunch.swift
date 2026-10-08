// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation
import os

/// Opens a screen straight away in debug builds, for screenshots:
/// launch with `-KitaeScreen workout`, `typing`, `finish`, `options` or `minimized`.
enum DebugLaunch {
    static let screen = UserDefaults.standard.string(forKey: "KitaeScreen")
    private static let log = Logger(subsystem: "ca.gureet.kitae", category: "debug")

    static func note(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }
    private static var opened: Set<String> = []

    /// True the first time a screen asks, so it only opens once per launch.
    static func consume(_ screen: String) -> Bool {
        opened.insert(screen).inserted
    }

    /// Starts an example workout 23 minutes in, with two exercises done and the rest timer running.
    static func prepare(_ model: AppModel) {
        guard let screen, ["workout", "typing", "finish", "options", "minimized"].contains(screen),
              let day = model.currentPlan.days.first else { return }
        let workout = Workout(
            day: day,
            planName: model.currentPlan.name,
            defaultRestSeconds: model.defaultRestSeconds,
            startedAt: Date.now.addingTimeInterval(-(23 * 60 + 36))
        )
        for exercise in workout.exercises.prefix(2) {
            for set in exercise.sets {
                workout.update(set.id) { $0.isDone = true }
            }
        }
        workout.startRest(seconds: 95)
        model.workout = workout
    }

    /// Whether the example workout should open, rather than stay minimized.
    static var opensWorkout: Bool {
        ["workout", "typing", "finish", "options"].contains(screen ?? "")
    }
}
#endif
