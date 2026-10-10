// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Picks an exercise to add to a day: search by name, or narrow it down by muscle.
struct ExercisePicker: View {
    let dayName: String
    /// The exercises the day has already. They're ticked and can't be added twice.
    let added: Set<Exercise.ID>
    let onPick: (Exercise) -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [Exercise] = []
    @State private var search = ""
    @State private var muscle: MuscleGroup?

    /// The order of the muscle chips and sections.
    static let muscles: [MuscleGroup] = [
        .chest, .upperBack, .lats, .shoulders, .biceps, .triceps,
        .traps, .core, .quads, .hamstrings, .glutes, .calves,
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.exercises) { exercise in
                            row(exercise)
                        }
                    } header: {
                        SectionCaption(".\(group.title.lowercased())")
                    }
                }
            }
            .listSectionSpacing(12)
            .environment(\.defaultMinListRowHeight, 52)
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .overlay {
                if groups.isEmpty, !exercises.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .safeAreaBar(edge: .top) {
                muscleChips
                    .padding(.vertical, 6)
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(exercises.count) exercises")
            .navigationTitle("Add to \(dayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .task {
            do {
                exercises = try model.database.read { db in try Exercises.all(db) }
            } catch {
                model.problem = "Couldn't read the exercises. \(error.localizedDescription)"
            }
        }
    }

    private var muscleChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                DayChip(title: "All", isSelected: muscle == nil) { muscle = nil }
                ForEach(Self.muscles) { group in
                    DayChip(title: group.name, isSelected: muscle == group) {
                        muscle = muscle == group ? nil : group
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }

    private func row(_ exercise: Exercise) -> some View {
        let isAdded = added.contains(exercise.id)
        return Button {
            onPick(exercise)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(exercise.name)
                    .foregroundStyle(isAdded ? Color.inkSoft : Color.ink)
                Spacer(minLength: 8)
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .fontWeight(.semibold)
                    .foregroundStyle(isAdded ? Color.olive : Color.inkFaint)
            }
            .contentShape(.rect)
        }
        .disabled(isAdded)
        .listRowBackground(Color.card)
        .accessibilityLabel(exercise.name)
        .accessibilityValue(isAdded ? "Already in \(dayName)" : "")
    }

    private var groups: [ExerciseGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let found = exercises.filter { exercise in
            (muscle == nil || exercise.muscle == muscle)
                && (query.isEmpty || exercise.name.localizedStandardContains(query))
        }
        var groups = Self.muscles.compactMap { group -> ExerciseGroup? in
            let items = found.filter { $0.muscle == group }
            return items.isEmpty ? nil : ExerciseGroup(title: group.name, exercises: items)
        }
        let others = found.filter { $0.muscle == nil }
        if !others.isEmpty {
            groups.append(ExerciseGroup(title: "Other", exercises: others))
        }
        return groups
    }
}

/// The exercises of one muscle, as a section of the list.
struct ExerciseGroup: Identifiable {
    let title: String
    let exercises: [Exercise]

    var id: String { title }
}
