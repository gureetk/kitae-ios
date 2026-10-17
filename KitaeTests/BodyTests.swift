// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import GRDB
import Testing
@testable import Kitae

/// Weigh-ins, the profile, and the energy workouts use.
struct BodyTests {
    @Test func theBodyTablesLeaveRoomsVersionAlone() throws {
        let database = try KitaeDatabase.inMemory()
        let (version, hash, tables) = try database.read { db in
            (
                try Int.fetchOne(db, sql: "PRAGMA user_version"),
                try String.fetchOne(db, sql: "SELECT identity_hash FROM room_master_table WHERE id = 42"),
                try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name LIKE 'body_%' ORDER BY name")
            )
        }
        #expect(version == Schema.version)
        #expect(hash == Schema.identityHash)
        #expect(tables == ["body_measurements", "body_profile"])
    }

    @Test func aDayHasOneWeighIn() throws {
        let database = try KitaeDatabase.inMemory()
        try database.write { db in
            try BodyStore.save(db, date: 100, weightKg: 80, bodyFatPercent: nil)
            try BodyStore.save(db, date: 100, weightKg: 79.5, bodyFatPercent: 18)
            try BodyStore.save(db, date: 98, weightKg: 81, bodyFatPercent: nil)
        }
        var log = try database.read(BodyStore.log)
        #expect(log.entries.map(\.date) == [98, 100])
        #expect(log.entries.last?.weightKg == 79.5 && log.entries.last?.bodyFatPercent == 18)

        // Moving a weigh-in to another day takes it off its old day.
        let moved = try #require(log.entries.first)
        try database.write { db in
            try BodyStore.save(db, date: 99, weightKg: 81, bodyFatPercent: nil, replacing: moved.id)
        }
        log = try database.read(BodyStore.log)
        #expect(log.entries.map(\.date) == [99, 100])

        // Without a weight or body fat, the day has nothing.
        try database.write { db in
            try BodyStore.save(db, date: 100, weightKg: nil, bodyFatPercent: nil)
        }
        #expect(try database.read(BodyStore.log).entries.map(\.date) == [99])
    }

    @Test func theProfileIsSavedAsAndroidWouldReadIt() throws {
        let database = try KitaeDatabase.inMemory()
        let profile = BodyProfile(heightCm: 178, birthDate: 9630, sex: .female, activityLevel: .moderatelyActive)
        try database.write { db in try BodyStore.save(db, profile: profile) }
        #expect(try database.read(BodyStore.log).profile == profile)
        let row = try #require(try database.read { db in try Row.fetchOne(db, sql: "SELECT * FROM body_profile") })
        #expect(row["id"] as Int64 == 1)
        #expect(row["sex"] as String == "Female")
        #expect(row["activityLevel"] as String == "ModeratelyActive")
    }

    @Test func aBackupFromAndroidGetsTheBodyTables() throws {
        let database = try KitaeDatabase.inMemory()
        try database.write { db in try BodyStore.save(db, date: 100, weightKg: 80, bodyFatPercent: nil) }
        // Room's tables only, as Kitae for Android makes them.
        let android = try DatabaseQueue()
        try android.write { db in try Schema.create(db) }
        try database.replaceContents(with: android)
        let log = try database.read(BodyStore.log)
        #expect(log.entries.isEmpty)
        try database.write { db in try BodyStore.save(db, date: 101, weightKg: 79, bodyFatPercent: nil) }
        #expect(try database.read(BodyStore.log).entries.count == 1)
    }

    @Test func aDayUsesTheLastWeightBeforeIt() {
        let log = BodyLog(entries: [
            BodyEntry(id: 1, date: 10, weightKg: 80, bodyFatPercent: 20),
            BodyEntry(id: 2, date: 20, weightKg: nil, bodyFatPercent: 19),
            BodyEntry(id: 3, date: 30, weightKg: 78, bodyFatPercent: nil),
        ])
        #expect(log.weightKg(on: 5) == 80)
        #expect(log.weightKg(on: 25) == 80)
        #expect(log.weightKg(on: 30) == 78)
        #expect(log.bodyFatPercent(on: 25) == 19)
        #expect(log.latestWeight?.id == 3)
        #expect(log.entries[0].leanKg == 64)
        #expect(BodyLog().weightKg(on: 10) == nil)
    }

    @Test func ageCountsWholeYears() {
        let profile = BodyProfile(birthDate: 9630) // 14 May 1996
        #expect(profile.age(on: 9630 + 365 * 30 + 6) == 29) // 7 May 2026
        #expect(profile.age(on: 9630 + 365 * 30 + 8) == 30) // 15 May 2026
    }

    private func workout(minutes: Int, sets: Int, date: Int = 100) -> WorkoutSummary {
        WorkoutSummary(id: 1, date: date, planID: nil, dayID: nil, dayName: "Push A", isFinished: true,
                       startedAt: 0, finishedAt: Int64(minutes) * 60_000, setCount: sets, doneCount: sets)
    }

    @Test func aWorkoutsEnergyIsWhatItAddsToResting() throws {
        // 80 kg for an hour: 3.5 kcal per kilogram an hour, less 1 at rest.
        let weightOnly = BodyLog(entries: [BodyEntry(id: 1, date: 90, weightKg: 80)])
        let plain = try #require(weightOnly.activeKilocalories(workout(minutes: 60, sets: 15)))
        #expect(abs(plain - 200) < 0.001)

        // Height, age and sex: Mifflin-St Jeor, 1780 kcal a day for this man of 30.
        var profiled = weightOnly
        profiled.profile = BodyProfile(heightCm: 180, birthDate: 100 - 365 * 30 - 20, sex: .male)
        let mifflin = try #require(profiled.activeKilocalories(workout(minutes: 60, sets: 15)))
        #expect(abs(mifflin - (280 - 1780.0 / 24)) < 0.001)

        // Body fat: Katch-McArdle, from 64 kg of lean mass.
        profiled.entries[0].bodyFatPercent = 20
        let katch = try #require(profiled.activeKilocalories(workout(minutes: 60, sets: 15)))
        #expect(abs(katch - (280 - (370 + 21.6 * 64) / 24)) < 0.001)
    }

    @Test func aWorkoutLeftRunningCountsSixMinutesASet() throws {
        let log = BodyLog(entries: [BodyEntry(id: 1, date: 90, weightKg: 80)])
        let overnight = try #require(log.activeKilocalories(workout(minutes: 300, sets: 10)))
        let hour = try #require(log.activeKilocalories(workout(minutes: 60, sets: 10)))
        #expect(overnight == hour)
    }

    @Test func noWeightOrNoSetsMeansNoEnergy() {
        #expect(BodyLog().activeKilocalories(workout(minutes: 60, sets: 15)) == nil)
        let log = BodyLog(entries: [BodyEntry(id: 1, date: 90, weightKg: 80)])
        #expect(log.activeKilocalories(workout(minutes: 60, sets: 0)) == nil)
        var unknownLength = workout(minutes: 60, sets: 15)
        unknownLength.startedAt = nil
        #expect(log.activeKilocalories(unknownLength) == nil)
    }

    @Test func theWeekAddsUpItsWorkouts() {
        let log = BodyLog(entries: [BodyEntry(id: 1, date: 90, weightKg: 80)])
        let totals = log.totals([workout(minutes: 60, sets: 15), workout(minutes: 30, sets: 8)])
        #expect(totals.workouts == 2 && totals.minutes == 90)
        #expect(abs((totals.kilocalories ?? 0) - 300) < 0.001)
        #expect(BodyLog().totals([workout(minutes: 60, sets: 15)]).kilocalories == nil)
    }

    @Test func weeksStartOnThePhonesFirstDay() {
        // 1 January 1970 was a Thursday.
        #expect(startOfWeek(0, firstWeekday: 1) == -4) // Sunday
        #expect(startOfWeek(0, firstWeekday: 2) == -3) // Monday
        #expect(startOfWeek(3, firstWeekday: 1) == 3) // Sunday 4 January
    }

    @Test func bodyWeightsAndPercentagesAreShownToATenth() {
        let kilograms = WeightFormatter(unit: .kilograms, decimals: .point)
        #expect(kilograms.body(kilograms: 78.44) == "78.4 kg")
        #expect(kilograms.percent(18) == "18%")
        #expect(kilograms.percent(18.25) == "18.3%")
        let pounds = WeightFormatter(unit: .pounds, decimals: .comma)
        #expect(pounds.body(kilograms: 80) == "176,4 lb")
        #expect(HeightFormatter(unit: .pounds).string(centimetres: 180) == "5 ft 11 in")
        #expect(HeightFormatter(unit: .kilograms).string(centimetres: 179.6) == "180 cm")
        #expect(kilocaloriesLabel(232) == "≈ 230 kcal")
    }
}
