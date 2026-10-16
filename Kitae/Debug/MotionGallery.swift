// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

#if DEBUG
import SwiftUI

/// Every exercise animation in one list, for checking them: launch with `-KitaeScreen motions`.
struct MotionGallery: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(ExerciseMotions.byID.values.sorted { $0.id < $1.id }) { motion in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(motion.id) · \(motion.name)")
                            .font(.kitaeMono(13, relativeTo: .footnote, bold: true))
                            .foregroundStyle(.inkSoft)
                            .padding(.horizontal, 8)
                        ExerciseMotionView(motion: motion)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.paper)
        .onAppear {
            DebugLaunch.note("motions appeared, \(ExerciseMotions.byID.count) animations")
        }
    }
}
#endif
