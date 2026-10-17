// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// How an exercise's sets use energy, for a workout's estimate (see `WorkoutEnergy`).
///
/// A rep costs `perKilogram` kcal for each kilogram it moves: the weight logged times
/// `loadFactor` (2 for a pair of dumbbells, less on a sled pushed at an angle), plus `bodyShare`
/// of the body's own weight (most of it in a squat or a pull-up, little in a curl), all times
/// `sides` for exercises done one side at a time. A hold costs `holdMETs` a second instead.
///
/// The costs per kilogram come from sets whose whole cost was measured, aerobic, anaerobic and
/// the recovery after (Scott et al. 2014, "Total Energy Costs – Aerobic and Anaerobic, Exercise
/// and Recovery – of Five Resistance Exercises"): about 0.0075 kcal per kilogram a rep for
/// squats, 0.012 for deadlifts, 0.011 for presses and 0.0034 for calf raises, with the body's
/// weight counted. Rows, pulls, curls and other lifts of the arms use the press's figure, and
/// bodyweight squats and push-ups match Nakagata et al. (2022).
nonisolated struct ExerciseEnergy: Equatable, Sendable {
    var perKilogram: Double
    var bodyShare: Double
    var loadFactor = 1.0
    var sides = 1.0
    /// For holds, whose reps are seconds: METs while holding.
    var holdMETs: Double?

    /// The most a set counts for, against typing slips.
    static let mostReps = 300
    static let mostKilograms = 600.0

    /// The energy of one set, in kcal, on top of resting.
    func kilocalories(reps: Int, weightKg: Double, bodyKg: Double) -> Double {
        let reps = Double(min(max(reps, 0), Self.mostReps))
        if let holdMETs {
            return max(holdMETs - 1, 0) * bodyKg * reps / 3600 * sides
        }
        let load = min(max(weightKg, 0), Self.mostKilograms)
        return perKilogram * (load * loadFactor + bodyShare * bodyKg) * reps * sides
    }

    // Kcal for each kilogram moved, each rep.
    private static let squat = 0.0075
    private static let hinge = 0.012
    private static let arms = 0.011
    private static let raise = 0.012
    private static let calf = 0.0034
    private static let legMachine = 0.008
    private static let core = 0.008

    /// Each starter exercise's, by its id. Dumbbells are counted as a pair at the weight of one,
    /// as people log them, and a side at a time as both sides done.
    static let starters: [Int64: ExerciseEnergy] = [
        1: .init(perKilogram: arms, bodyShare: 0.02, loadFactor: 2), // Curls
        2: .init(perKilogram: arms, bodyShare: 0.02), // Barbell Curls
        3: .init(perKilogram: arms, bodyShare: 0.02), // Preacher Curls
        4: .init(perKilogram: arms, bodyShare: 0.02, loadFactor: 2), // Incline Bicep Curls
        5: .init(perKilogram: arms, bodyShare: 0.02), // Tricep Push Down
        6: .init(perKilogram: arms, bodyShare: 0.02), // Skull-Crushers
        7: .init(perKilogram: arms, bodyShare: 0.02), // Overhead Extensions
        8: .init(perKilogram: raise, bodyShare: 0.03, loadFactor: 2), // Lateral Raises
        9: .init(perKilogram: arms, bodyShare: 0.05, loadFactor: 2), // Shoulder Press
        10: .init(perKilogram: arms, bodyShare: 0.03), // Face Pulls
        11: .init(perKilogram: squat, bodyShare: 0.85), // Squats
        12: .init(perKilogram: squat, bodyShare: 0.15, loadFactor: 0.7), // Leg Press
        13: .init(perKilogram: squat, bodyShare: 0.7, loadFactor: 0.7), // Hack Squats
        14: .init(perKilogram: hinge, bodyShare: 0.55), // Stiff Legged Deadlift
        15: .init(perKilogram: legMachine, bodyShare: 0.1), // Lying Leg Curls
        16: .init(perKilogram: calf, bodyShare: 1), // Calf Raises
        17: .init(perKilogram: 0.007, bodyShare: 0.4), // Hip Thrusts
        18: .init(perKilogram: squat, bodyShare: 0.85, loadFactor: 2), // Lunges
        19: .init(perKilogram: core, bodyShare: 0.5), // Sit-ups
        20: .init(perKilogram: core, bodyShare: 0.3), // Leg Raises
        21: .init(perKilogram: arms, bodyShare: 0.05), // Bench Press
        22: .init(perKilogram: arms, bodyShare: 0.05), // Incline Bench
        23: .init(perKilogram: arms, bodyShare: 0.02), // Pec Dec
        24: .init(perKilogram: arms, bodyShare: 0.02, loadFactor: 2), // Chest Fly
        25: .init(perKilogram: 0.007, bodyShare: 0, loadFactor: 2), // Shrugs
        26: .init(perKilogram: arms, bodyShare: 0.05), // Lat Pull-down
        27: .init(perKilogram: arms, bodyShare: 0.95), // Pull-ups
        28: .init(perKilogram: arms, bodyShare: 0.1), // Lat Prayers
        29: .init(perKilogram: arms, bodyShare: 0.1), // Bent-over Rows
        30: .init(perKilogram: arms, bodyShare: 0.05, loadFactor: 2), // Chest-Supported Rows
        31: .init(perKilogram: legMachine, bodyShare: 0.05), // Leg Extensions
        32: .init(perKilogram: arms, bodyShare: 0.01, sides: 2), // Behind-the-Back Bicep Curls
        33: .init(perKilogram: squat, bodyShare: 0.85), // Smith-Squats
        34: .init(perKilogram: raise, bodyShare: 0.015, sides: 2), // Cable Lateral Raises
        35: .init(perKilogram: arms, bodyShare: 0.04), // Upright Rows
        36: .init(perKilogram: arms, bodyShare: 0.05, loadFactor: 2), // Dumbbell Bench Press
        37: .init(perKilogram: arms, bodyShare: 0.05, loadFactor: 2), // Incline Dumbbell Press
        38: .init(perKilogram: arms, bodyShare: 0.05), // Decline Bench Press
        39: .init(perKilogram: arms, bodyShare: 0.02, loadFactor: 2), // Cable Crossovers
        40: .init(perKilogram: 0.014, bodyShare: 0.64), // Push-ups
        41: .init(perKilogram: arms, bodyShare: 0.05), // Machine Chest Press
        42: .init(perKilogram: arms, bodyShare: 0.95), // Chin-ups
        43: .init(perKilogram: arms, bodyShare: 0.05), // Straight-Arm Pulldowns
        44: .init(perKilogram: arms, bodyShare: 0.05), // Seated Cable Rows
        45: .init(perKilogram: arms, bodyShare: 0.05, sides: 2), // Single-Arm Dumbbell Rows
        46: .init(perKilogram: arms, bodyShare: 0.1), // T-Bar Rows
        47: .init(perKilogram: 0.0124, bodyShare: 0.6), // Deadlift
        48: .init(perKilogram: arms, bodyShare: 0.05), // Overhead Press
        49: .init(perKilogram: arms, bodyShare: 0.05, loadFactor: 2), // Arnold Press
        50: .init(perKilogram: raise, bodyShare: 0.03, loadFactor: 2), // Front Raises
        51: .init(perKilogram: raise, bodyShare: 0.03, loadFactor: 2), // Rear Delt Flyes
        52: .init(perKilogram: arms, bodyShare: 0.02, loadFactor: 2), // Hammer Curls
        53: .init(perKilogram: arms, bodyShare: 0.02), // Cable Curls
        54: .init(perKilogram: arms, bodyShare: 0.01, sides: 2), // Concentration Curls
        55: .init(perKilogram: arms, bodyShare: 0.95), // Dips
        56: .init(perKilogram: arms, bodyShare: 0.05), // Close-Grip Bench Press
        57: .init(perKilogram: arms, bodyShare: 0.01, sides: 2), // Tricep Kickbacks
        58: .init(perKilogram: squat, bodyShare: 0.85), // Front Squats
        59: .init(perKilogram: squat, bodyShare: 0.8, loadFactor: 2, sides: 2), // Bulgarian Split Squats
        60: .init(perKilogram: squat, bodyShare: 0.85), // Goblet Squats
        61: .init(perKilogram: 0, bodyShare: 0, holdMETs: 3.5), // Wall Sit
        62: .init(perKilogram: hinge, bodyShare: 0.55), // Romanian Deadlift
        63: .init(perKilogram: legMachine, bodyShare: 0.05), // Seated Leg Curls
        64: .init(perKilogram: hinge, bodyShare: 0.55), // Good Mornings
        65: .init(perKilogram: 0.007, bodyShare: 0.4), // Glute Bridges
        66: .init(perKilogram: arms, bodyShare: 0.15, sides: 2), // Cable Kickbacks
        67: .init(perKilogram: 0.006, bodyShare: 0), // Hip Abductions
        68: .init(perKilogram: calf, bodyShare: 0), // Seated Calf Raises
        69: .init(perKilogram: 0, bodyShare: 0, holdMETs: 3.5), // Plank
        70: .init(perKilogram: 0, bodyShare: 0, sides: 2, holdMETs: 3), // Side Plank
        71: .init(perKilogram: 0.006, bodyShare: 0.35), // Crunches
        72: .init(perKilogram: 0.006, bodyShare: 0.35), // Cable Crunches
        73: .init(perKilogram: 0.004, bodyShare: 0.3), // Russian Twists
        74: .init(perKilogram: 0.012, bodyShare: 0.35), // Hanging Leg Raises
        75: .init(perKilogram: 0.011, bodyShare: 0.55), // Ab Wheel Rollouts
    ]

    /// A starter exercise's own, or for people's own exercises, one for their muscle group, or
    /// a hold for isometric ones.
    static func of(exerciseID: Int64, target: String, isIsometric: Bool) -> ExerciseEnergy {
        if let starter = starters[exerciseID] { return starter }
        if isIsometric { return ExerciseEnergy(perKilogram: 0, bodyShare: 0, holdMETs: 3.5) }
        switch MuscleGroup(rawValue: target) {
        case .biceps, .triceps: return ExerciseEnergy(perKilogram: arms, bodyShare: 0.02)
        case .shoulders: return ExerciseEnergy(perKilogram: arms, bodyShare: 0.04)
        case .chest, .lats, .upperBack: return ExerciseEnergy(perKilogram: arms, bodyShare: 0.05)
        case .traps: return ExerciseEnergy(perKilogram: 0.007, bodyShare: 0)
        case .quads: return ExerciseEnergy(perKilogram: squat, bodyShare: 0.4)
        case .glutes: return ExerciseEnergy(perKilogram: 0.007, bodyShare: 0.3)
        case .hamstrings: return ExerciseEnergy(perKilogram: 0.009, bodyShare: 0.2)
        case .calves: return ExerciseEnergy(perKilogram: calf, bodyShare: 0.5)
        case .core: return ExerciseEnergy(perKilogram: core, bodyShare: 0.35)
        case nil: return ExerciseEnergy(perKilogram: 0.01, bodyShare: 0.2)
        }
    }
}

nonisolated extension SetType {
    /// How much more a set of this type costs than its logged reps and weight show.
    ///
    /// Sets taken to failure cost more for the same work, as extra anaerobic and recovery
    /// energy (Scott & Earnest 2011): single bench press sets to failure measured about 43 and
    /// 60 kJ (Scott et al. 2011) where the same lab's sets stopped short of failure come to
    /// about 26 and 45 kJ for the same work (Scott et al. 2014), a third to two thirds more.
    /// Kitae counts 30%, at the low end, as sets logged as standard are often close to failure
    /// too. Drop and rest-pause sets go to failure as well, and their drops and mini-sets are
    /// logged as sets of their own, so they count the same: with the same weight lifted, drop
    /// sets cost no more than straight sets (Enes et al. 2024). A warm-up counts for its own,
    /// lighter weight.
    var energyFactor: Double {
        switch self {
        case .warmup, .standard: 1
        case .failure, .drop, .restPause: 1.3
        }
    }
}
