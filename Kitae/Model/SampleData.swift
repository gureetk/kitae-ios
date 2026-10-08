// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Example plans, used until Kitae has its database.
enum SampleData {
    static func plans() -> [Plan] {
        var builder = Builder()
        return [
            builder.plan("Push Pull Legs", days: [
                ("Push A", [
                    ("Incline Bench", .chest, nil, [(.warmup, 12, 20), (.standard, 10, 22.5), (.standard, 10, 22.5)]),
                    ("Chest Fly", .chest, nil, [(.standard, 12, 12.5), (.standard, 12, 12.5), (.failure, 9, 12.5)]),
                    ("Shoulder Press", .shoulders, nil, [(.standard, 10, 17.5), (.standard, 10, 17.5), (.standard, 8, 17.5)]),
                    ("Lateral Raises", .shoulders, 60, [(.standard, 12, 7.5), (.standard, 12, 7.5), (.standard, 12, 7.5)]),
                    ("Tricep Push Down", .triceps, 60, [(.standard, 12, 25), (.standard, 12, 25), (.standard, 12, 25)]),
                ]),
                ("Pull A", [
                    ("Lat Pull-down", .lats, nil, [(.warmup, 12, 30), (.standard, 10, 45), (.standard, 10, 45)]),
                    ("Seated Cable Rows", .back, nil, [(.standard, 12, 40), (.standard, 12, 40), (.standard, 12, 40)]),
                    ("Face Pulls", .shoulders, 60, [(.standard, 15, 15), (.standard, 15, 15), (.standard, 15, 15)]),
                    ("Hammer Curls", .biceps, 60, [(.standard, 10, 12), (.standard, 10, 12), (.standard, 10, 12)]),
                    ("Shrugs", .traps, 60, [(.standard, 12, 24), (.standard, 12, 24), (.standard, 12, 24)]),
                ]),
                ("Legs", [
                    ("Squats", .quads, 150, [(.warmup, 10, 40), (.standard, 8, 70), (.standard, 8, 70), (.standard, 6, 75)]),
                    ("Romanian Deadlift", .hamstrings, 120, [(.standard, 10, 60), (.standard, 10, 60), (.standard, 10, 60)]),
                    ("Leg Extensions", .quads, nil, [(.standard, 12, 45), (.standard, 12, 45), (.standard, 12, 45)]),
                    ("Lying Leg Curls", .hamstrings, nil, [(.standard, 12, 35), (.standard, 12, 35), (.standard, 12, 35)]),
                    ("Calf Raises", .calves, 60, [(.standard, 15, 60), (.standard, 15, 60), (.standard, 15, 60)]),
                ]),
                ("Push B", [
                    ("Bench Press", .chest, 150, [(.warmup, 10, 40), (.standard, 8, 60), (.standard, 8, 60), (.standard, 8, 60)]),
                    ("Overhead Press", .shoulders, 120, [(.standard, 8, 35), (.standard, 8, 35), (.standard, 8, 35)]),
                    ("Incline Dumbbell Press", .chest, nil, [(.standard, 10, 20), (.standard, 10, 20), (.drop, 8, 15)]),
                    ("Cable Lateral Raises", .shoulders, 60, [(.standard, 15, 5), (.standard, 15, 5), (.standard, 15, 5)]),
                    ("Dips", .triceps, nil, [(.standard, 10, 0), (.standard, 10, 0), (.failure, 8, 0)]),
                ]),
                ("Pull B", [
                    ("Pull-ups", .lats, 120, [(.standard, 8, 0), (.standard, 8, 0), (.standard, 6, 0)]),
                    ("Bent-over Rows", .back, nil, [(.standard, 10, 40), (.standard, 10, 40), (.standard, 10, 40)]),
                    ("Rear Delt Flyes", .shoulders, 60, [(.standard, 15, 6), (.standard, 15, 6), (.standard, 15, 6)]),
                    ("Barbell Curls", .biceps, nil, [(.standard, 10, 25), (.standard, 10, 25), (.restPause, 12, 20)]),
                    ("Cable Curls", .biceps, 60, [(.standard, 12, 15), (.standard, 12, 15), (.standard, 12, 15)]),
                ]),
            ]),
            builder.plan("Upper Lower", days: [
                ("Upper", [
                    ("Bench Press", .chest, 150, [(.warmup, 10, 40), (.standard, 6, 65), (.standard, 6, 65)]),
                    ("Bent-over Rows", .back, nil, [(.standard, 8, 45), (.standard, 8, 45), (.standard, 8, 45)]),
                    ("Overhead Press", .shoulders, 120, [(.standard, 8, 35), (.standard, 8, 35)]),
                    ("Chin-ups", .lats, 120, [(.standard, 8, 0), (.standard, 8, 0)]),
                ]),
                ("Lower", [
                    ("Squats", .quads, 150, [(.warmup, 10, 40), (.standard, 6, 80), (.standard, 6, 80)]),
                    ("Romanian Deadlift", .hamstrings, 120, [(.standard, 8, 70), (.standard, 8, 70)]),
                    ("Bulgarian Split Squats", .quads, nil, [(.standard, 10, 16), (.standard, 10, 16)]),
                    ("Calf Raises", .calves, 60, [(.standard, 15, 60), (.standard, 15, 60)]),
                ]),
            ]),
            builder.plan("Full Body", days: [
                ("Day A", [
                    ("Squats", .quads, 150, [(.standard, 5, 80), (.standard, 5, 80), (.standard, 5, 80)]),
                    ("Bench Press", .chest, 150, [(.standard, 5, 60), (.standard, 5, 60), (.standard, 5, 60)]),
                    ("Bent-over Rows", .back, nil, [(.standard, 8, 45), (.standard, 8, 45)]),
                ]),
                ("Day B", [
                    ("Deadlift", .hamstrings, 180, [(.standard, 5, 100), (.standard, 5, 100)]),
                    ("Overhead Press", .shoulders, 120, [(.standard, 5, 40), (.standard, 5, 40), (.standard, 5, 40)]),
                    ("Pull-ups", .lats, 120, [(.standard, 8, 0), (.standard, 8, 0)]),
                ]),
            ]),
        ]
    }

    typealias SetSpec = (type: SetType, reps: Int, kg: Double)
    typealias ExerciseSpec = (name: String, target: MuscleGroup, rest: Int?, sets: [SetSpec])

    private struct Builder {
        var nextID: Int64 = 1
        var exercises: [String: Exercise] = [:]

        mutating func id() -> Int64 {
            defer { nextID += 1 }
            return nextID
        }

        mutating func exercise(_ name: String, _ target: MuscleGroup, rest: Int?) -> Exercise {
            if let known = exercises[name] { return known }
            let made = Exercise(id: id(), name: name, target: target, restSeconds: rest)
            exercises[name] = made
            return made
        }

        mutating func plan(_ name: String, days: [(String, [ExerciseSpec])]) -> Plan {
            let planID = id()
            let builtDays = days.map { dayName, items in
                TrainingDay(id: id(), name: dayName, exercises: items.map { item in
                    DayExercise(
                        id: id(),
                        exercise: exercise(item.name, item.target, rest: item.rest),
                        sets: item.sets.map { PlannedSet(id: id(), type: $0.type, reps: $0.reps, weightKg: $0.kg) }
                    )
                })
            }
            return Plan(id: planID, name: name, days: builtDays)
        }
    }
}
