// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@main
struct KitaeApp: App {
    @State private var launch = Launch.open()

    init() {
        KitaeFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .ready(let model):
                RootView(model: model)
                    .overlay {
                        #if DEBUG
                        if let page = DebugLaunch.galleryPage {
                            RestActivityGallery(page: page)
                        }
                        #endif
                    }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Kitae can't open its data", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
            }
        }
    }
}

/// Opens the database when Kitae starts.
enum Launch {
    case ready(AppModel)
    case failed(String)

    static func open() -> Launch {
        do {
            #if DEBUG
            // Example data for screenshots, kept away from the real database.
            if DebugLaunch.usesExampleData {
                let model = AppModel(database: try .inMemory(), restStore: .none, restAlerts: false)
                DebugLaunch.prepare(model)
                return .ready(model)
            }
            #endif
            return .ready(AppModel(database: try .app()))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
