// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct SetOptionsTarget: Identifiable {
    let id: WorkoutSet.ID
}

/// Opens from a set's label: its type, its rest and deleting it.
struct SetOptionsSheet: View {
    let workout: Workout
    let target: SetOptionsTarget
    let defaultRestSeconds: Int
    @Environment(\.dismiss) private var dismiss

    private static let restChoices = [30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SetType.allCases) { type in
                        Button {
                            workout.update(target.id) { $0.type = type }
                        } label: {
                            HStack(spacing: 14) {
                                Text(type.letter ?? "01")
                                    .font(.kitaeMono(15, relativeTo: .body, bold: true))
                                    .foregroundStyle(.inkSoft)
                                    .frame(width: 30, alignment: .leading)
                                Text(type.name)
                                    .foregroundStyle(.ink)
                                Spacer()
                                if set?.type == type {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.olive)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .accessibilityAddTraits(set?.type == type ? .isSelected : [])
                        .listRowBackground(Color.card)
                    }
                } header: {
                    Text(".set type")
                        .font(.kitaeMono(12, relativeTo: .caption))
                        .textCase(nil)
                }

                Section {
                    Picker("Rest after this set", selection: restSelection) {
                        Text("Default, \(restLabel(seconds: exerciseRest))").tag(Int?.none)
                        ForEach(Self.restChoices, id: \.self) { seconds in
                            Text(restLabel(seconds: seconds)).tag(Int?.some(seconds))
                        }
                    }
                    .listRowBackground(Color.card)
                }

                Section {
                    Button("Delete set", role: .destructive) {
                        dismiss()
                        workout.deleteSet(target.id)
                    }
                    .listRowBackground(Color.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle(exercise?.exercise.name ?? "Set")
            .navigationSubtitle("set \(liveLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.68), .large])
    }

    private var set: WorkoutSet? { workout.set(target.id) }
    private var exercise: WorkoutExercise? { workout.exercise(containing: target.id) }

    /// The set's label as it is now, so changing its type to failure turns 03 into F1.
    private var liveLabel: String {
        guard let exercise, let index = exercise.sets.firstIndex(where: { $0.id == target.id }) else { return "" }
        return setLabels(for: exercise.sets.map(\.type))[index]
    }

    private var exerciseRest: Int {
        exercise?.exercise.restSeconds ?? defaultRestSeconds
    }

    private var restSelection: Binding<Int?> {
        Binding(
            get: { set?.restSeconds },
            set: { seconds in workout.update(target.id) { $0.restSeconds = seconds } }
        )
    }
}
