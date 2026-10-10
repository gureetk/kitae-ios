// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation
import os

/// Opens a screen straight away in debug builds, for screenshots: launch with
/// `-KitaeScreen today`, `workout`, `typing`, `finish`, `options`, `minimized` or `switch`.
/// These use a database in memory, so the real one isn't touched.
enum DebugLaunch {
    static let screen = UserDefaults.standard.string(forKey: "KitaeScreen")
    private static let log = Logger(subsystem: "ca.gureet.kitae", category: "debug")
    private static let workoutScreens: Set = ["workout", "typing", "finish", "options", "minimized", "switch"]
    private static var opened: Set<String> = []

    static func note(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }

    /// Whether this launch is for a screenshot.
    static var usesExampleData: Bool {
        guard let screen else { return false }
        return screen == "today" || workoutScreens.contains(screen)
    }

    /// True the first time a screen asks, so it only opens once per launch.
    static func consume(_ screen: String) -> Bool {
        opened.insert(screen).inserted
    }

    /// Starts an example workout 23 minutes in, with two exercises done and the rest timer running.
    static func prepare(_ model: AppModel) {
        guard let screen, workoutScreens.contains(screen), let day = model.selectedDay else { return }
        model.startWorkout(day, at: Date.now.addingTimeInterval(-(23 * 60 + 36)))
        guard let workout = model.workout else { return }
        for exercise in workout.exercises.prefix(2) {
            for set in exercise.sets {
                workout.toggleDone(set.id)
            }
        }
        workout.startRest(seconds: 95)
        model.isWorkoutPresented = false
    }

    /// Whether the example workout should open, rather than stay minimized.
    static var opensWorkout: Bool {
        ["workout", "typing", "finish", "options"].contains(screen ?? "")
    }
}
#endif
