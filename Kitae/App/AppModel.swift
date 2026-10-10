// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation
import os

/// What the whole app is showing: the plans, the day that's up next, and the workout in
/// progress. Everything comes from the database and goes straight back into it.
@Observable
final class AppModel {
    let database: KitaeDatabase
    private(set) var plans: [PlanSummary] = []
    /// The plan being followed, with its days. nil until a plan is chosen.
    private(set) var currentPlan: Plan?
    /// The day after the last one done, which Today offers unless another day is picked.
    private(set) var upNextDayID: TrainingDay.ID?
    /// Whether any set was ever done, in the workout in progress too. Until then Today says
    /// it's the first session.
    var hasDoneSets: Bool { hadDoneSets || (workout?.doneCount ?? 0) > 0 }
    /// Whether any set was done as of the last time the database was read.
    private var hadDoneSets = false
    /// A day picked on Today instead of the one up next.
    var pickedDayID: TrainingDay.ID?
    private(set) var workout: Workout?
    var isWorkoutPresented = false
    var weightFormatter = WeightFormatter()
    var defaultRestSeconds = 90
    /// Something that went wrong, to tell people about.
    var problem: String?

    /// The time, which tests can set.
    @ObservationIgnored var clock: () -> Date = { .now }

    private static let log = Logger(subsystem: "ca.gureet.kitae", category: "app")

    init(database: KitaeDatabase) {
        self.database = database
        reload()
    }

    var days: [TrainingDay] { currentPlan?.days ?? [] }

    /// The day Today shows: the one picked, else the one in progress, else the one up next.
    var selectedDay: TrainingDay? {
        if let id = pickedDayID, let day = days.first(where: { $0.id == id }) { return day }
        if let id = workout?.dayID, let day = days.first(where: { $0.id == id }) { return day }
        return days.first { $0.id == upNextDayID } ?? days.first
    }

    /// Reads the plans and the workout in progress again.
    func reload() {
        let today = EpochDay.of(clock())
        do {
            let snapshot = try database.read { db in
                let currentID = try Plans.currentID(db)
                return (
                    plans: try Plans.all(db),
                    plan: try currentID.flatMap { try Plans.plan(db, id: $0) },
                    lastDone: try Sessions.lastDoneDayID(db),
                    hasDoneSets: try Sessions.hasDoneSets(db),
                    active: try Sessions.active(db, today: today)
                )
            }
            plans = snapshot.plans
            currentPlan = snapshot.plan
            upNextDayID = Plans.dayAfter(snapshot.lastDone, in: snapshot.plan?.days ?? [])?.id
            hadDoneSets = snapshot.hasDoneSets
            if let active = snapshot.active {
                if workout?.id != active.id {
                    workout = try makeWorkout(id: active.id)
                }
            } else {
                isWorkoutPresented = false
                workout = nil
            }
        } catch {
            report(error, "Couldn't read your plans")
        }
    }

    /// Follows another plan from today.
    func selectPlan(_ id: Plan.ID) {
        guard id != currentPlan?.id else { return }
        let today = EpochDay.of(clock())
        do {
            try database.write { db in try Plans.setCurrent(db, planID: id, today: today) }
        } catch {
            report(error, "Couldn't switch plans")
        }
        pickedDayID = nil
        reload()
    }

    /// Starts a workout of `day`, or opens it if it's the one in progress.
    func startWorkout(_ day: TrainingDay, at time: Date? = nil) {
        if let workout {
            if workout.dayID == day.id { isWorkoutPresented = true }
            return
        }
        let now = time ?? clock()
        do {
            let id = try database.write { db in
                try Sessions.start(db, dayID: day.id, today: EpochDay.of(now), now: now.epochMilliseconds)
            }
            workout = try makeWorkout(id: id)
            pickedDayID = nil
            isWorkoutPresented = workout != nil
        } catch {
            report(error, "Couldn't start \(day.name)")
        }
    }

    /// Ends the workout. Today moves on to the plan's next day.
    func finishWorkout(_ mode: FinishMode, addNewSets: Bool) {
        guard let workout else { return }
        workout.skipRest()
        let sessionID = workout.id
        let now = clock().epochMilliseconds
        do {
            try database.write { db in
                try Sessions.finish(db, sessionID: sessionID, mode: mode, addNewSets: addNewSets, now: now)
            }
        } catch {
            report(error, "Couldn't finish the workout")
            return
        }
        close()
    }

    /// Removes the workout and its sets. The plan stays the same.
    func discardWorkout() {
        guard let workout else { return }
        workout.skipRest()
        let sessionID = workout.id
        do {
            try database.write { db in try Sessions.discard(db, sessionID: sessionID) }
        } catch {
            report(error, "Couldn't discard the workout")
            return
        }
        close()
    }

    private func close() {
        isWorkoutPresented = false
        workout = nil
        pickedDayID = nil
        reload()
    }

    private func makeWorkout(id: Int64) throws -> Workout? {
        try Workout(
            id: id,
            database: database,
            defaultRestSeconds: defaultRestSeconds,
            defaultWeightKg: weightFormatter.unit.defaultWeightKg
        )
    }

    private func report(_ error: any Error, _ message: String) {
        Self.log.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        problem = "\(message). \(error.localizedDescription)"
    }
}
