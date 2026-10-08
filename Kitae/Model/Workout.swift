// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Observation

nonisolated struct WorkoutSet: Identifiable, Hashable, Sendable {
    var id: Int64
    var type: SetType
    var reps: Int
    var weightKg: Double
    var restSeconds: Int?
    var isDone = false
    /// Added during the workout rather than planned.
    var isAdded = false
}

nonisolated struct WorkoutExercise: Identifiable, Hashable, Sendable {
    var id: Int64
    var exercise: Exercise
    var sets: [WorkoutSet]
}

/// A workout in progress: the day's sets, which are done, and the rest timer.
@Observable
final class Workout: Identifiable {
    let id = UUID()
    let planName: String
    let day: TrainingDay
    let startedAt: Date
    var exercises: [WorkoutExercise]
    var rest = RestTimer()
    /// Goes up each time a rest runs out, so the screen can tap the phone.
    private(set) var restsFinished = 0

    private let defaultRestSeconds: Int
    private var nextSetID: Int64
    @ObservationIgnored private var restEnd: Task<Void, Never>?

    init(day: TrainingDay, planName: String, defaultRestSeconds: Int, startedAt: Date = .now) {
        self.day = day
        self.planName = planName
        self.startedAt = startedAt
        self.defaultRestSeconds = defaultRestSeconds
        let exercises = day.exercises.map { item in
            WorkoutExercise(
                id: item.id,
                exercise: item.exercise,
                sets: item.sets.map {
                    WorkoutSet(id: $0.id, type: $0.type, reps: $0.reps, weightKg: $0.weightKg, restSeconds: $0.restSeconds)
                }
            )
        }
        self.exercises = exercises
        nextSetID = (exercises.flatMap(\.sets).map(\.id).max() ?? 0) + 1
    }

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var doneCount: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isDone).count } }
    var notDoneCount: Int { setCount - doneCount }
    var addedDoneCount: Int { exercises.reduce(0) { $0 + $1.sets.filter { $0.isAdded && $0.isDone }.count } }

    func set(_ id: WorkoutSet.ID) -> WorkoutSet? {
        for exercise in exercises {
            if let found = exercise.sets.first(where: { $0.id == id }) { return found }
        }
        return nil
    }

    func exercise(containing setID: WorkoutSet.ID) -> WorkoutExercise? {
        exercises.first { $0.sets.contains { $0.id == setID } }
    }

    func update(_ id: WorkoutSet.ID, _ change: (inout WorkoutSet) -> Void) {
        for e in exercises.indices {
            if let s = exercises[e].sets.firstIndex(where: { $0.id == id }) {
                change(&exercises[e].sets[s])
                return
            }
        }
    }

    /// Ticks a set off, or unticks it. Ticking starts the rest timer.
    func toggleDone(_ id: WorkoutSet.ID) {
        var nowDone = false
        update(id) {
            $0.isDone.toggle()
            nowDone = $0.isDone
        }
        if nowDone, let set = set(id), let exercise = exercise(containing: id) {
            startRest(seconds: set.restSeconds ?? exercise.exercise.restSeconds ?? defaultRestSeconds)
        }
    }

    /// Adds a set like the exercise's last one.
    func addSet(to exerciseID: WorkoutExercise.ID) {
        guard let e = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let last = exercises[e].sets.last
        exercises[e].sets.append(WorkoutSet(
            id: nextSetID,
            type: last?.type == .warmup ? .standard : (last?.type ?? .standard),
            reps: last?.reps ?? 10,
            weightKg: last?.weightKg ?? 0,
            restSeconds: last?.restSeconds,
            isAdded: true
        ))
        nextSetID += 1
    }

    func deleteSet(_ id: WorkoutSet.ID) {
        for e in exercises.indices {
            exercises[e].sets.removeAll { $0.id == id }
        }
    }

    // MARK: Rest timer

    func startRest(seconds: Int) {
        rest.start(seconds: seconds, at: .now)
        scheduleRestEnd()
    }

    func pauseRest() {
        rest.pause(at: .now)
        restEnd?.cancel()
    }

    func resumeRest() {
        rest.resume(at: .now)
        scheduleRestEnd()
    }

    func addRest(_ seconds: TimeInterval) {
        rest.add(seconds, at: .now)
        scheduleRestEnd()
    }

    func skipRest() {
        rest.stop()
        restEnd?.cancel()
    }

    private func scheduleRestEnd() {
        restEnd?.cancel()
        guard let endsAt = rest.endsAt else { return }
        restEnd = Task { [weak self] in
            let delay = endsAt.timeIntervalSinceNow
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            guard !Task.isCancelled, let self, self.rest.endsAt == endsAt else { return }
            self.rest.stop()
            self.restsFinished += 1
        }
    }
}
