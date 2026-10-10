// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import Foundation
import os

/// Opens a screen straight away in debug builds, for screenshots: launch with
/// `-KitaeScreen today`, `workout`, `typing`, `finish`, `options`, `minimized` or `switch`;
/// `activity` and `activitystates` for the Lock Screen and Dynamic Island rest timer;
/// `plans` for the first launch and `newplan` for naming a new plan; or `planedit`, `planset`,
/// `plansettyping`, `addexercise`, `newday` and `firstday` for the plan editor, and `editworkout` and
/// `workoutedit` for it while a workout is going, from Today and from the workout.
/// These use a database in memory, so the real one isn't touched, and they don't ask for alerts.
enum DebugLaunch {
    static let screen = UserDefaults.standard.string(forKey: "KitaeScreen")
    private static let log = Logger(subsystem: "ca.gureet.kitae", category: "debug")
    private static let workoutScreens: Set = [
        "workout", "typing", "finish", "options", "minimized", "switch", "editworkout", "workoutedit",
    ]
    private static let editorScreens: Set = [
        "planedit", "planset", "plansettyping", "addexercise", "newday", "editworkout",
    ]
    /// Screens that make a new plan to show it.
    private static let newPlanScreens: Set = ["firstday"]
    /// Screens of the first launch, before a plan is chosen.
    private static let firstLaunchScreens: Set = ["plans", "newplan"]
    private static var opened: Set<String> = []

    static func note(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }

    /// Whether this launch is for a screenshot.
    static var usesExampleData: Bool {
        guard let screen else { return false }
        return screen == "today" || workoutScreens.contains(screen) || editorScreens.contains(screen)
            || newPlanScreens.contains(screen) || firstLaunchScreens.contains(screen) || galleryPage != nil
    }

    /// The rest timer's Lock Screen and Dynamic Island looks, drawn in the app.
    static var galleryPage: String? {
        ["activity", "activitystates"].contains(screen ?? "") ? screen : nil
    }

    /// Whether Today opens the plan editor straight away.
    static var opensPlanEditor: Bool {
        editorScreens.contains(screen ?? "")
    }

    /// True the first time a screen asks, so it only opens once per launch.
    static func consume(_ screen: String) -> Bool {
        opened.insert(screen).inserted
    }

    /// Follows the starter plan, unless the screen is of the first launch. For the workout
    /// screens, starts an example workout 23 minutes in, with two exercises done and the rest
    /// timer running.
    static func prepare(_ model: AppModel) {
        guard let screen else { return }
        if !firstLaunchScreens.contains(screen), let plan = model.plans.first {
            model.selectPlan(plan.id)
        }
        guard workoutScreens.contains(screen), let day = model.selectedDay else { return }
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
        ["workout", "typing", "finish", "options", "workoutedit"].contains(screen ?? "")
    }
}
#endif
