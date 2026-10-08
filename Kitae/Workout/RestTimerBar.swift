// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The rest timer at the bottom of the workout: time left, pause, −15s, +15s and skip.
struct RestTimerBar: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 0) {
            timeLeft
                .font(.kitaeMono(22, relativeTo: .title3, bold: true))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if workout.rest.isPaused { workout.resumeRest() } else { workout.pauseRest() }
            } label: {
                Image(systemName: workout.rest.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(workout.rest.isPaused ? "Resume rest" : "Pause rest")

            Button { workout.addRest(-15) } label: {
                Text("−15s").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("15 seconds less")

            Button { workout.addRest(15) } label: {
                Text("+15s").frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("15 seconds more")

            Button { workout.skipRest() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Skip rest")
        }
        .font(.kitaeMono(14, relativeTo: .subheadline))
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 58)
        .background(.mauveSoft, in: .capsule)
        .foregroundStyle(.onMauveSoft)
    }

    @ViewBuilder
    private var timeLeft: some View {
        if let endsAt = workout.rest.endsAt {
            Text(timerInterval: min(Date.now, endsAt)...endsAt, countsDown: true)
                .accessibilityLabel("Rest")
        } else {
            Text(restLabel(seconds: Int(workout.rest.remaining(at: .now).rounded(.up))))
                .opacity(0.55)
                .accessibilityLabel("Rest paused")
        }
    }
}
