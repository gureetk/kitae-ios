// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct KitaeApp: App {
    init() {
        KitaeFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
