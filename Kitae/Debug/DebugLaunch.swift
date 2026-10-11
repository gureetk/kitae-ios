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
/// `workoutedit` for it while a workout is going, from Today and from the workout; `history` and
/// `workoutdetail` for History, `exercises` and `exercise` for Exercises, and `you` and `settings`
/// for You, with five weeks of example workouts.
/// These use a database in memory, so the real one isn't touched, and they don't ask for alerts.
enum DebugLaunch {
    static let screen = UserDefaults.standard.string(forKey: "KitaeScreen")
    private static let log = Logger(subsystem: "ca.gureet.kitae", category: "debug")
    private static let workoutScreens: Set = [
        "workout", "typing", "finish", "options", "minimized", "switch", "editworkout", "workoutedit", "history",
    ]
    private static let historyScreens: Set = ["history", "workoutdetail"]
    private static let exerciseScreens: Set = ["exercises", "exercise"]
    private static let youScreens: Set = ["you", "settings"]
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
            || newPlanScreens.contains(screen) || firstLaunchScreens.contains(screen)
            || historyScreens.contains(screen) || exerciseScreens.contains(screen) || youScreens.contains(screen)
            || galleryPage != nil
    }

    /// The rest timer's Lock Screen and Dynamic Island looks, drawn in the app.
    static var galleryPage: String? {
        ["activity", "activitystates"].contains(screen ?? "") ? screen : nil
    }

    /// Whether Kitae opens on History.
    static var opensHistory: Bool {
        historyScreens.contains(screen ?? "")
    }

    /// Whether Kitae opens on Exercises.
    static var opensExercises: Bool {
        exerciseScreens.contains(screen ?? "")
    }

    /// Whether Kitae opens on You.
    static var opensYou: Bool {
        youScreens.contains(screen ?? "")
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
        if historyScreens.contains(screen) || exerciseScreens.contains(screen) || youScreens.contains(screen) {
            addExampleHistory(to: model)
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

    /// Five weeks of finished workouts of the plan's days in turn, every other day or so, with
    /// the weights going up a little each time and one workout skipped.
    private static func addExampleHistory(to model: AppModel) {
        guard let days = model.currentPlan?.days, !days.isEmpty else { return }
        let today = EpochDay.of(.now)
        let daysAgo = [36, 34, 33, 31, 29, 27, 26, 24, 22, 20, 19, 17, 15, 13, 12, 10, 8, 6, 5, 3, 1]
        do {
            try model.database.write { db in
                for (index, ago) in daysAgo.enumerated() {
                    let day = days[index % days.count]
                    let date = today - ago
                    let start = EpochDay.date(date).addingTimeInterval(TimeInterval(17 * 3600 + (index % 4) * 1500))
                    let sessionID = try Sessions.start(db, dayID: day.id, today: date, now: start.epochMilliseconds)
                    if ago != 8 {
                        let sets = try Sessions.exercises(db, sessionID: sessionID, dayID: day.id).flatMap(\.sets)
                        for var set in sets {
                            set.weightKg += 1.25
                            try Sessions.update(db, set: set)
                            try Sessions.setDone(db, setID: set.id, isDone: true)
                        }
                    }
                    let minutes = 41 + (index * 7) % 24
                    let end = start.addingTimeInterval(TimeInterval(minutes * 60))
                    try Sessions.finish(db, sessionID: sessionID, mode: .keepSkipped, addNewSets: false, now: end.epochMilliseconds)
                }
            }
        } catch {
            note("Couldn't add the example history: \(error)")
        }
        model.reload()
    }

    /// Whether the example workout should open, rather than stay minimized.
    static var opensWorkout: Bool {
        ["workout", "typing", "finish", "options", "workoutedit"].contains(screen ?? "")
    }
}
#endif
