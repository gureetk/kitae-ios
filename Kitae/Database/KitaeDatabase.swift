// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB

nonisolated enum KitaeDatabaseError: Error, LocalizedError {
    case missingSeed
    case unsupportedVersion(Int)
    case notKitae
    case missingDay(Int64)

    var errorDescription: String? {
        switch self {
        case .missingSeed:
            "Kitae's starter exercises are missing from the app."
        case .unsupportedVersion(let version):
            "This data is from a different version of Kitae (database version \(version)). Update Kitae and try again."
        case .notKitae:
            "This isn't Kitae's data."
        case .missingDay(let id):
            "Day \(id) isn't in any plan any more."
        }
    }
}

/// Where Kitae keeps plans, workouts and exercises: one SQLite file, laid out exactly like
/// Kitae for Android's (see `Schema`).
nonisolated final class KitaeDatabase: Sendable {
    let writer: any DatabaseWriter

    /// Opens the database at `writer`, setting it up first if it's new.
    init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try writer.write { db in
            try Self.prepare(db)
        }
    }

    /// The app's database. It has Kitae for Android's file name, so backups line up.
    static func app() throws -> KitaeDatabase {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let path = folder.appendingPathComponent("kenko_database").path
        var configuration = Configuration()
        configuration.label = "Kitae"
        return try KitaeDatabase(DatabasePool(path: path, configuration: configuration))
    }

    /// A database that lives only in memory, for tests and debug screens.
    static func inMemory() throws -> KitaeDatabase {
        try KitaeDatabase(DatabaseQueue())
    }

    func read<T>(_ value: (Database) throws -> T) throws -> T {
        try writer.read(value)
    }

    /// Runs `updates` in one transaction: all of it is saved, or none.
    @discardableResult
    func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try writer.write(updates)
    }

    /// Makes the tables in a new database and adds the starter exercises and plan. No plan is
    /// followed until people pick one, as in Kitae for Android. An existing database has to be
    /// version 8.
    private static func prepare(_ db: Database) throws {
        let version = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
        if version == Schema.version {
            let hash = try String.fetchOne(db, sql: "SELECT identity_hash FROM room_master_table WHERE id = 42")
            guard hash == Schema.identityHash else { throw KitaeDatabaseError.notKitae }
            return
        }
        guard version == 0 else { throw KitaeDatabaseError.unsupportedVersion(version) }
        let tables = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'") ?? 0
        guard tables == 0 else { throw KitaeDatabaseError.notKitae }

        try Schema.create(db)
        try Seed.bundled().insert(db)
    }
}
