// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The workout in progress: every exercise's sets, the rest timer and Finish.
struct WorkoutView: View {
    @Environment(AppModel.self) private var model
    let workout: Workout

    @FocusState private var focus: SetField?
    @State private var optionsFor: SetOptionsTarget?
    @State private var finishStep: FinishStep?
    @State private var confirmsDiscard = false
    @State private var showsPlanEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(workout.exercises) { exercise in
                        exerciseSection(exercise)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .safeAreaBar(edge: .bottom) {
                // The bottom of the safe area sits on top of the keyboard while one is up.
                if focus == nil {
                    bottomBar
                } else {
                    keyboardBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mainToolbar }
            .confirmationDialog("Discard workout?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { model.discardWorkout() }
            } message: {
                Text("This workout and its sets will be removed. Your plan stays the same.")
            }
        }
        .sheet(item: $optionsFor) { target in
            SetOptionsSheet(workout: workout, target: target, defaultRestSeconds: model.defaultRestSeconds)
        }
        .sheet(isPresented: $showsPlanEditor) {
            ComingSoonSheet(title: "Plan editor", message: "Editing plans comes in a later batch.")
        }
        .sensoryFeedback(.success, trigger: workout.doneCount) { old, new in new > old }
        .sensoryFeedback(.warning, trigger: workout.restsFinished)
        .task { await openDebugScreen() }
    }

    // MARK: Exercises and sets

    private func exerciseSection(_ exercise: WorkoutExercise) -> some View {
        let labels = setLabels(for: exercise.sets.map(\.type))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(exercise.exercise.name)
                    .font(.kitaeDisplay(26, relativeTo: .title2))
                    .foregroundStyle(.olive)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button {
                    workout.addSet(to: exercise.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(.oliveSoft, in: .circle)
                        .foregroundStyle(.onOliveSoft)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a set to \(exercise.exercise.name)")
            }
            .padding(.leading, 8)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRow(
                    set: set,
                    label: labels[index],
                    formatter: model.weightFormatter,
                    focus: $focus,
                    onReps: { reps in workout.update(set.id) { $0.reps = reps } },
                    onWeight: { kg in workout.update(set.id) { $0.weightKg = kg } },
                    onToggleDone: { workout.toggleDone(set.id) },
                    onOptions: { optionsFor = SetOptionsTarget(id: set.id) }
                )
            }
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if workout.rest.isActive {
                RestTimerBar(workout: workout)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            Button {
                startFinishing()
            } label: {
                HStack(spacing: 8) {
                    Text("Finish")
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                }
                .font(.kitaeMono(16, relativeTo: .headline, bold: true))
                .frame(maxWidth: .infinity, minHeight: 58)
            }
            .buttonStyle(MauveButtonStyle())
            .frame(width: workout.rest.isActive ? 100 : nil)
            .confirmationDialog(
                finishTitle,
                isPresented: Binding(get: { finishStep != nil }, set: { if !$0 { finishStep = nil } }),
                titleVisibility: .visible,
                presenting: finishStep
            ) { step in
                finishActions(step)
            } message: { step in
                Text(finishMessage(step))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .animation(.snappy, value: workout.rest.isActive)
    }

    // MARK: Toolbars

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Minimize workout", systemImage: "chevron.down") {
                model.isWorkoutPresented = false
            }
        }
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(workout.day.name)
                    .font(.kitaeDisplay(24, relativeTo: .headline))
                    .foregroundStyle(.ink)
                HStack(spacing: 0) {
                    Text(timerInterval: workout.startedAt...Date.distantFuture, countsDown: false)
                    Text(" · \(workout.doneCount)/\(workout.setCount) sets")
                }
                .font(.kitaeMono(12, relativeTo: .caption))
                .foregroundStyle(.inkSoft)
            }
            .accessibilityElement(children: .combine)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Edit \(workout.day.name)", systemImage: "pencil") {
                showsPlanEditor = true
            }
            Menu("More", systemImage: "ellipsis") {
                Button("Discard workout", systemImage: "trash", role: .destructive) {
                    confirmsDiscard = true
                }
            }
        }
    }

    /// Steps for the field being typed in, and Next, just above the keyboard.
    private var keyboardBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                switch focus {
                case .weight(let id)?:
                    ForEach(model.weightFormatter.unit.steps, id: \.self) { step in
                        stepButton((step < 0 ? "−" : "+") + stepNumber(abs(step))) { changeWeight(id, by: step) }
                            .accessibilityLabel("\(step < 0 ? "Minus" : "Plus") \(stepNumber(abs(step))) \(model.weightFormatter.unit.symbol)")
                    }
                case .reps(let id)?:
                    stepButton("−1") { workout.update(id) { $0.reps = max($0.reps - 1, 0) } }
                        .accessibilityLabel("One rep less")
                    stepButton("+1") { workout.update(id) { $0.reps += 1 } }
                        .accessibilityLabel("One rep more")
                case nil:
                    EmptyView()
                }
            }
            .padding(.horizontal, 4)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer(minLength: 0)

            Button {
                focus = nextField
            } label: {
                Text(nextField == nil ? "Done" : "Next")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.olive)
                    .padding(.horizontal, 20)
                    .frame(minHeight: 48)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func stepButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.kitaeMono(15, relativeTo: .body))
                .foregroundStyle(.ink)
                .frame(minWidth: 52, minHeight: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var orderedFields: [SetField] {
        workout.exercises.flatMap { exercise in
            exercise.sets.flatMap { [SetField.reps($0.id), SetField.weight($0.id)] }
        }
    }

    private var nextField: SetField? {
        guard let focus, let index = orderedFields.firstIndex(of: focus), index + 1 < orderedFields.count else {
            return nil
        }
        return orderedFields[index + 1]
    }

    /// 5 or 2.5, written with the decimal separator from Settings.
    private func stepNumber(_ size: Double) -> String {
        if size == size.rounded() { return "\(Int(size))" }
        let formatter = model.weightFormatter
        let separator = formatter.decimals.separator(for: formatter.locale)
        return "\(Int(size))\(separator)\(Int((size * 10).rounded()) % 10)"
    }

    private func changeWeight(_ id: WorkoutSet.ID, by step: Double) {
        let unit = model.weightFormatter.unit
        workout.update(id) { set in
            let shown = unit.fromKilograms(set.weightKg)
            set.weightKg = unit.toKilograms(max(shown + step, 0))
        }
    }

    // MARK: Finishing

    enum FinishStep {
        case unfinished(Int)
        case nothingDone
        case addedSets(Int)
    }

    private func startFinishing() {
        if workout.doneCount == 0 {
            finishStep = .nothingDone
        } else if workout.notDoneCount > 0 {
            finishStep = .unfinished(workout.notDoneCount)
        } else if workout.addedDoneCount > 0 {
            finishStep = .addedSets(workout.addedDoneCount)
        } else {
            model.finishWorkout()
        }
    }

    private var finishTitle: String {
        switch finishStep {
        case .addedSets: "Keep the new sets?"
        default: "Finish workout?"
        }
    }

    private func finishMessage(_ step: FinishStep) -> String {
        let day = workout.day.name
        switch step {
        case .unfinished(1):
            return "1 set isn't done. Skipping it keeps \(day) as it is. Removing it also takes it out of the plan."
        case .unfinished(let count):
            return "\(count) sets aren't done. Skipping them keeps \(day) as it is. Removing them also takes them out of the plan."
        case .nothingDone:
            return "Nothing was done in this workout. Keep it as skipped, or discard it? Your plan stays the same either way."
        case .addedSets(1):
            return "You added 1 set. Add it to \(day) for next time?"
        case .addedSets(let count):
            return "You added \(count) sets. Add them to \(day) for next time?"
        }
    }

    @ViewBuilder
    private func finishActions(_ step: FinishStep) -> some View {
        switch step {
        case .unfinished:
            Button("Keep as skipped") { askAboutAddedSetsOrFinish() }
            Button("Remove from plan", role: .destructive) { askAboutAddedSetsOrFinish() }
        case .nothingDone:
            Button("Keep as skipped") { model.finishWorkout() }
            Button("Discard workout", role: .destructive) { model.discardWorkout() }
        case .addedSets:
            Button("Add to \(workout.day.name)") { model.finishWorkout() }
            Button("Only this workout") { model.finishWorkout() }
        }
    }

    /// The second question, about sets added during the workout, comes once the first has closed.
    private func askAboutAddedSetsOrFinish() {
        let added = workout.addedDoneCount
        guard added > 0 else {
            model.finishWorkout()
            return
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            finishStep = .addedSets(added)
        }
    }

    // MARK: Debug

    private func openDebugScreen() async {
        #if DEBUG
        DebugLaunch.note("workout appeared, screen \(DebugLaunch.screen ?? "none")")
        guard let screen = DebugLaunch.screen, DebugLaunch.consume(screen) else { return }
        try? await Task.sleep(for: .milliseconds(700))
        let firstUnfinished = workout.exercises.flatMap(\.sets).first { !$0.isDone }
        DebugLaunch.note("opening \(screen), first unfinished set \(firstUnfinished?.id ?? -1)")
        switch screen {
        case "typing":
            if let set = firstUnfinished {
                workout.update(set.id) { $0.weightKg = 18.75 }
                focus = .weight(set.id)
            }
        case "finish":
            startFinishing()
        case "options":
            if let set = firstUnfinished { optionsFor = SetOptionsTarget(id: set.id) }
        default:
            break
        }
        #endif
    }
}
