// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A set's type. The raw values are how Kitae for Android stores them, so backups
/// stay compatible: don't rename them.
nonisolated enum SetType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case warmup = "Warmup"
    case standard = "Standard"
    case failure = "Failure"
    case drop = "Drop"
    case restPause = "RestPause"

    var id: Self { self }

    var name: String {
        switch self {
        case .warmup: "Warm-up"
        case .standard: "Standard"
        case .failure: "Failure"
        case .drop: "Drop set"
        case .restPause: "Rest-pause"
        }
    }

    /// The letter in a set's label, like the W in W1. Standard sets only have a number.
    var letter: String? {
        switch self {
        case .warmup: "W"
        case .standard: nil
        case .failure: "F"
        case .drop: "D"
        case .restPause: "R"
        }
    }
}

/// Labels sets the way Kitae does: W1, 01, 02, F1, D1, R1. Each type is counted on its
/// own, so standard sets are numbered 01, 02… however many warm-ups come first.
nonisolated func setLabels(for types: [SetType]) -> [String] {
    var counts: [SetType: Int] = [:]
    return types.map { type in
        let number = (counts[type] ?? 0) + 1
        counts[type] = number
        if let letter = type.letter {
            return "\(letter)\(number)"
        }
        return number < 10 ? "0\(number)" : "\(number)"
    }
}

/// The muscle an exercise mainly works. Raw values match Kitae for Android.
nonisolated enum MuscleGroup: String, CaseIterable, Identifiable, Hashable, Sendable {
    case biceps = "Biceps"
    case triceps = "Triceps"
    case shoulders = "Shoulders"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case calves = "Calves"
    case glutes = "Glutes"
    case core = "Core"
    case chest = "Chest"
    case back = "Back"
    case lats = "Lats"
    case traps = "Traps"

    var id: Self { self }
    var name: String { rawValue }
}

nonisolated struct Exercise: Identifiable, Hashable, Sendable {
    var id: Int64
    var name: String
    var target: MuscleGroup
    var isIsometric = false
    /// Rest after each set of this exercise, unless the set has its own. nil uses the default.
    var restSeconds: Int?
}

/// A set as it's planned for a training day.
nonisolated struct PlannedSet: Identifiable, Hashable, Sendable {
    var id: Int64
    var type: SetType = .standard
    var reps: Int
    /// Always kilograms. Settings decides the unit people see.
    var weightKg: Double
    /// Rest after this set. nil uses the exercise's rest, or the default.
    var restSeconds: Int?
}

nonisolated struct DayExercise: Identifiable, Hashable, Sendable {
    var id: Int64
    var exercise: Exercise
    var sets: [PlannedSet]
}

/// A named training day, like Push A or Legs.
nonisolated struct TrainingDay: Identifiable, Hashable, Sendable {
    var id: Int64
    var name: String
    var exercises: [DayExercise]

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
}

nonisolated struct Plan: Identifiable, Hashable, Sendable {
    var id: Int64
    var name: String
    var days: [TrainingDay]

    var exerciseCount: Int {
        Set(days.flatMap { $0.exercises.map(\.exercise.id) }).count
    }
}

/// "1 set", "15 sets". Kitae's text is English only for now.
nonisolated func counted(_ count: Int, _ singular: String, _ plural: String) -> String {
    "\(count) \(count == 1 ? singular : plural)"
}

/// A rest length as Kitae shows it: 90 seconds is 1:30.
nonisolated func restLabel(seconds: Int) -> String {
    let minutes = seconds / 60
    let rest = seconds % 60
    return "\(minutes):\(rest < 10 ? "0" : "")\(rest)"
}
