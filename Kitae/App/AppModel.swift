// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation

/// What the whole app is showing: the plans, the day that's up next, and the workout in progress.
@Observable
final class AppModel {
    var plans: [Plan]
    var currentPlanID: Plan.ID {
        didSet {
            if oldValue != currentPlanID { selectedDayID = currentPlan.days.first?.id }
        }
    }
    var selectedDayID: TrainingDay.ID?
    var workout: Workout?
    var isWorkoutPresented = false
    var weightFormatter = WeightFormatter()
    var defaultRestSeconds = 90

    init(plans: [Plan]) {
        self.plans = plans
        currentPlanID = plans.first?.id ?? 0
        selectedDayID = plans.first?.days.first?.id
    }

    static func sample() -> AppModel {
        AppModel(plans: SampleData.plans())
    }

    var currentPlan: Plan {
        plans.first { $0.id == currentPlanID } ?? Plan(id: 0, name: "No plan", days: [])
    }

    var selectedDay: TrainingDay? {
        currentPlan.days.first { $0.id == selectedDayID } ?? currentPlan.days.first
    }

    func startWorkout(_ day: TrainingDay) {
        if workout?.day.id != day.id {
            workout = Workout(day: day, planName: currentPlan.name, defaultRestSeconds: defaultRestSeconds)
        }
        isWorkoutPresented = true
    }

    /// Ends the workout and moves on to the plan's next day.
    func finishWorkout() {
        if let finished = workout?.day, let index = currentPlan.days.firstIndex(where: { $0.id == finished.id }) {
            let days = currentPlan.days
            selectedDayID = days[(index + 1) % days.count].id
        }
        isWorkoutPresented = false
        workout = nil
    }

    func discardWorkout() {
        isWorkoutPresented = false
        workout = nil
    }
}
