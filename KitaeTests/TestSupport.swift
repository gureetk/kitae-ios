// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
@testable import Kitae

extension KitaeDatabase {
    /// A new database in memory that follows the starter plan from `today`, as if it was
    /// chosen on first launch.
    static func followingStarterPlan(today: Int = 20_736) throws -> KitaeDatabase {
        let database = try KitaeDatabase.inMemory()
        try database.write { db in
            guard let planID = try Int64.fetchOne(db, sql: "SELECT id FROM plans ORDER BY id LIMIT 1") else {
                throw KitaeDatabaseError.missingSeed
            }
            try Plans.setCurrent(db, planID: planID, today: today)
        }
        return database
    }
}

extension AppModel {
    /// A model on `database` that keeps nothing outside it: no settings, backups, Lock Screen
    /// timer or alerts.
    static func testing(_ database: KitaeDatabase, restStore: RestTimerStore = .none) -> AppModel {
        AppModel(
            database: database,
            restStore: restStore,
            settingsStore: .none,
            backups: .none,
            liveActivities: false,
            restAlerts: false
        )
    }
}

extension Data {
    /// Bytes written out in hexadecimal, like "0a0f".
    init?(hex: String) {
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
