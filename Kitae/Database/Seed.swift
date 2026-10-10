// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

/// What a new database starts with: Kitae for Android's exercises, with the same ids, and its
/// starter plan. `Seed.json` is made from Kitae for Android's starter database by
/// `scripts/make_seed.py`.
nonisolated struct Seed: Decodable, Sendable {
    nonisolated struct Exercise: Decodable, Sendable {
        var id: Int64
        var name: String
        var target: String
        var isIsometric: Bool
        var reference: String?
        var restSeconds: Int?
        var instructions: String?
    }

    nonisolated struct Plan: Decodable, Sendable {
        var name: String
        var description: String?
        var difficulty: String?
        var focus: String?
        var equipment: String?
        var time: String?
        var days: [Day]
    }

    nonisolated struct Day: Decodable, Sendable {
        var name: String
        var exercises: [DayExercise]
    }

    nonisolated struct DayExercise: Decodable, Sendable {
        var exercise: Int64
        var sets: [PlannedSet]
    }

    nonisolated struct PlannedSet: Decodable, Sendable {
        var reps: Int
        var weight: Double
        var type: String
        var restSeconds: Int?
    }

    var exercises: [Exercise]
    var plans: [Plan]

    static func bundled() throws -> Seed {
        guard let url = Bundle.main.url(forResource: "Seed", withExtension: "json") else {
            throw KitaeDatabaseError.missingSeed
        }
        return try JSONDecoder().decode(Seed.self, from: Data(contentsOf: url))
    }

    /// Adds the exercises and plans. Returns the id of the first plan.
    @discardableResult
    func insert(_ db: Database) throws -> Int64? {
        for exercise in exercises {
            try db.execute(
                sql: """
                INSERT INTO `exercises` (`id`, `name`, `target`, `reference`, `isIsometric`, `restSeconds`, `instructions`)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    exercise.id, exercise.name, exercise.target, exercise.reference,
                    exercise.isIsometric, exercise.restSeconds, exercise.instructions,
                ]
            )
        }
        var firstPlanID: Int64?
        for plan in plans {
            try db.execute(
                sql: """
                INSERT INTO `plans` (`name`, `description`, `difficulty`, `focus`, `equipment`, `time`)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [plan.name, plan.description, plan.difficulty, plan.focus, plan.equipment, plan.time]
            )
            let planID = db.lastInsertedRowID
            firstPlanID = firstPlanID ?? planID
            for (dayPosition, day) in plan.days.enumerated() {
                try db.execute(
                    sql: "INSERT INTO `routines` (`planId`, `name`, `position`) VALUES (?, ?, ?)",
                    arguments: [planID, day.name, dayPosition]
                )
                let routineID = db.lastInsertedRowID
                for (exercisePosition, item) in day.exercises.enumerated() {
                    try db.execute(
                        sql: "INSERT INTO `routine_exercises` (`routineId`, `exerciseId`, `position`) VALUES (?, ?, ?)",
                        arguments: [routineID, item.exercise, exercisePosition]
                    )
                    let slotID = db.lastInsertedRowID
                    for (setPosition, set) in item.sets.enumerated() {
                        try db.execute(
                            sql: """
                            INSERT INTO `routine_sets` (`routineExerciseId`, `reps`, `weight`, `type`, `position`, `restSeconds`)
                            VALUES (?, ?, ?, ?, ?, ?)
                            """,
                            arguments: [slotID, set.reps, set.weight, set.type, setPosition, set.restSeconds]
                        )
                    }
                }
            }
        }
        return firstPlanID
    }
}
