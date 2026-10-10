// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

enum AppTab: Hashable {
    case today
    case history
    case exercises
    case you
}

/// The four tabs, the workout bar above them, and the workout itself.
struct RootView: View {
    @Bindable var model: AppModel
    @State private var tab = AppTab.today
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "dumbbell", value: .today) {
                TodayView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: .history) {
                ComingSoonTab(title: "History", systemImage: "clock.arrow.circlepath", message: "Every workout you finish will be listed here.")
            }
            Tab("Exercises", systemImage: "list.bullet", value: .exercises) {
                ComingSoonTab(title: "Exercises", systemImage: "list.bullet", message: "Kitae's exercises, with how to do them and your progress.")
            }
            Tab("You", systemImage: "person", value: .you) {
                ComingSoonTab(title: "You", systemImage: "person", message: "Your plan, your stats, and settings.")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .workoutAccessory(model.workout != nil) {
            WorkoutAccessory()
        }
        .fullScreenCover(isPresented: $model.isWorkoutPresented) {
            if let workout = model.workout {
                WorkoutView(workout: workout)
                    .environment(model)
            }
        }
        .environment(model)
        .tint(.olive)
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.problem != nil }, set: { if !$0 { model.problem = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.problem ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.sceneBecameActive() }
        }
        .task {
            #if DEBUG
            // A cover asked for before the first frame doesn't open, so wait a moment.
            if DebugLaunch.opensWorkout {
                try? await Task.sleep(for: .milliseconds(400))
                model.isWorkoutPresented = true
            }
            #endif
        }
    }
}
