// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The first tab: the day that's up next in the current plan, and a button to start it.
struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var line = TodayLines.random()
    @State private var switchingTo: TrainingDay?
    @State private var showsPlanEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let day = model.selectedDay {
                    VStack(alignment: .leading, spacing: 0) {
                        header(day)
                        dayChips
                            .padding(.top, 28)
                        startButton(day)
                            .padding(.top, 18)
                            .padding(.horizontal, 24)
                        Text(line)
                            .font(.kitaeMono(12, relativeTo: .caption))
                            .foregroundStyle(.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                        exerciseList(day)
                            .padding(.top, 44)
                            .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 24)
                } else {
                    ContentUnavailableView("No days yet", systemImage: "calendar", description: Text("Add a training day to this plan to start."))
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { planMenu }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit \(model.selectedDay?.name ?? "plan")", systemImage: "pencil") {
                        showsPlanEditor = true
                    }
                }
            }
            .sheet(isPresented: $showsPlanEditor) {
                ComingSoonSheet(title: "Plan editor", message: "Editing plans comes in a later batch.")
            }
            .confirmationDialog(
                "Workout in progress",
                isPresented: Binding(get: { switchingTo != nil }, set: { if !$0 { switchingTo = nil } }),
                titleVisibility: .visible,
                presenting: switchingTo
            ) { day in
                Button("Finish it and start \(day.name)") {
                    model.finishWorkout()
                    model.selectedDayID = day.id
                    model.startWorkout(day)
                }
                Button("Continue \(model.workout?.day.name ?? "workout")") {
                    model.isWorkoutPresented = true
                }
            } message: { day in
                Text("\(model.workout?.day.name ?? "Your workout") isn't finished yet. Finish it and start \(day.name)?")
            }
        }
    }

    private func header(_ day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Caption(status(for: day), size: 14)
            Text(day.name)
                .font(.kitaeDisplay(112))
                .foregroundStyle(.olive)
                .lineLimit(2)
                .minimumScaleFactor(0.4)
                // Darker Grotesque's line height leaves a lot of air at this size.
                .padding(.top, -22)
                .padding(.bottom, -12)
                .padding(.leading, -4)
                .accessibilityAddTraits(.isHeader)
            Caption("\(counted(day.exercises.count, "exercise", "exercises")) · \(counted(day.setCount, "set", "sets"))", size: 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func status(for day: TrainingDay) -> String {
        model.workout?.day.id == day.id ? ".in progress" : ".up next"
    }

    private var dayChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(model.currentPlan.days) { day in
                    DayChip(title: day.name, isSelected: day.id == model.selectedDay?.id) {
                        model.selectedDayID = day.id
                    }
                }
            }
        }
        .contentMargins(.horizontal, 24, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func startButton(_ day: TrainingDay) -> some View {
        let continues = model.workout?.day.id == day.id
        return Button {
            if let current = model.workout, current.day.id != day.id {
                switchingTo = day
            } else {
                model.startWorkout(day)
            }
        } label: {
            HStack(spacing: 10) {
                Text(continues ? "Continue" : "Start")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 58)
        }
        .buttonStyle(MauveButtonStyle())
    }

    private func exerciseList(_ day: TrainingDay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Caption(".exercises")
                .padding(.leading, 8)
            VStack(spacing: 0) {
                ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.exercise.name)
                        Spacer()
                        Text(counted(item.sets.count, "set", "sets"))
                            .font(.kitaeMono(13, relativeTo: .footnote))
                            .foregroundStyle(.inkSoft)
                    }
                    .padding(.horizontal, 18)
                    .frame(minHeight: 54)
                    if index < day.exercises.count - 1 {
                        Hairline().padding(.leading, 18)
                    }
                }
            }
            .background(.card, in: .rect(cornerRadius: 24))
        }
    }

    private var planMenu: some View {
        Menu {
            Picker("Plan", selection: Binding(get: { model.currentPlanID }, set: { model.currentPlanID = $0 })) {
                ForEach(model.plans) { plan in
                    Text(plan.name).tag(plan.id)
                }
            }
            .disabled(model.workout != nil)
        } label: {
            HStack(spacing: 6) {
                Text(model.currentPlan.name)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(.ink)
        }
        .accessibilityLabel("Plan: \(model.currentPlan.name)")
    }
}

/// Short lines under the Start button, one per launch.
enum TodayLines {
    static let all = [
        "show up, tick it off",
        "forged one set at a time",
        "small plates add up",
        "rest, breathe, go again",
        "the next rep is the one that counts",
        "consistency beats intensity",
    ]

    static func random() -> String {
        all.randomElement() ?? all[0]
    }
}
