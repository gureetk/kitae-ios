// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// An estimate of the energy a workout used on top of resting: its active energy, as Apple
/// Health counts it, so a calorie tracker can add it to the day without counting resting energy
/// twice. It needs a weight; the rest of the profile makes it closer.
///
/// Weight training with several exercises of 8 to 15 reps is 3.5 METs in the 2024 Adult
/// Compendium of Physical Activities (code 02054), and a MET is about 1 kcal for each kilogram
/// an hour, so a workout uses 3.5 kcal per kilogram an hour. Resting energy is taken off: from
/// lean mass when body fat is known (Katch-McArdle), else from weight, height, age and sex
/// (Mifflin-St Jeor), else 1 kcal per kilogram an hour. A workout counts for at most six
/// minutes for each set done, so one left running after the last set isn't counted as hours of
/// training. Workouts without a known length, or without a set done, have none.
nonisolated enum WorkoutEnergy {
    static let met = 3.5
    static let longestMinutesPerSet = 6.0

    /// Kilocalories a day at rest.
    static func restingPerDay(weightKg: Double, bodyFatPercent: Double?, profile: BodyProfile, on day: Int) -> Double {
        if let bodyFatPercent, (2...70).contains(bodyFatPercent) {
            return 370 + 21.6 * weightKg * (1 - bodyFatPercent / 100)
        }
        if let height = profile.heightCm, let age = profile.age(on: day), let sex = profile.sex {
            let mifflin = 10 * weightKg + 6.25 * height - 5 * Double(age) + (sex == .male ? 5 : -161)
            if mifflin > 0 { return mifflin }
        }
        return 24 * weightKg
    }

    /// Active kilocalories for `minutes` of weight training.
    static func active(minutes: Double, weightKg: Double, restingPerDay: Double) -> Double {
        let hours = minutes / 60
        return max(met * weightKg * hours - restingPerDay / 24 * hours, 0)
    }

    /// The minutes a workout counts for.
    static func countedMinutes(_ workout: WorkoutSummary) -> Double? {
        guard workout.isFinished, workout.doneCount > 0, let milliseconds = workout.durationMilliseconds else {
            return nil
        }
        return min(Double(milliseconds) / 60_000, Double(workout.doneCount) * longestMinutesPerSet)
    }
}

nonisolated extension BodyLog {
    /// A finished workout's active energy, or nil when Kitae can't tell: no weight yet, no set
    /// done, or the workout's length isn't known.
    func activeKilocalories(_ workout: WorkoutSummary) -> Double? {
        guard let minutes = WorkoutEnergy.countedMinutes(workout), let weight = weightKg(on: workout.date) else {
            return nil
        }
        let resting = WorkoutEnergy.restingPerDay(
            weightKg: weight,
            bodyFatPercent: bodyFatPercent(on: workout.date),
            profile: profile,
            on: workout.date
        )
        return WorkoutEnergy.active(minutes: minutes, weightKg: weight, restingPerDay: resting)
    }

    /// The workouts of a stretch of days, their minutes, and their active energy when a weight
    /// is known.
    func totals(_ workouts: [WorkoutSummary]) -> WorkoutTotals {
        let done = workouts.filter { $0.isFinished && $0.doneCount > 0 }
        let energies = done.map { activeKilocalories($0) }
        return WorkoutTotals(
            workouts: done.count,
            minutes: done.compactMap(\.minutes).reduce(0, +),
            kilocalories: latestWeight == nil ? nil : energies.compactMap { $0 }.reduce(0, +)
        )
    }
}

/// What the You tab counts for this week.
nonisolated struct WorkoutTotals: Equatable, Sendable {
    var workouts = 0
    var minutes = 0
    /// nil until a weight is known.
    var kilocalories: Double?
}

/// The first day of the week `today` is in, on the phone's first day of the week.
nonisolated func startOfWeek(_ today: Int, firstWeekday: Int) -> Int {
    today - (weekday(ofEpochDay: today) - firstWeekday + 7) % 7
}
