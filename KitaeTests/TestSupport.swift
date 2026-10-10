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
