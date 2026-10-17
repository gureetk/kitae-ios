// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI
import Testing
@testable import Kitae

/// The muscle map: that every starter exercise has its muscles, and that the map can show them.
struct ExerciseMusclesTests {
    private func map() throws -> MuscleMap {
        let url = try #require(Bundle.main.url(forResource: "ExerciseMuscles", withExtension: "json"))
        return try ExerciseMuscles.decode(Data(contentsOf: url))
    }

    /// The starter exercises' names by id, from Seed.json.
    private func starterNames() throws -> [Int64: String] {
        let url = try #require(Bundle.main.url(forResource: "Seed", withExtension: "json"))
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var names: [Int64: String] = [:]
        for exercise in try #require(json["exercises"] as? [[String: Any]]) {
            names[Int64(try #require(exercise["id"] as? Int))] = try #require(exercise["name"] as? String)
        }
        return names
    }

    @Test func everyStarterExerciseHasItsMusclesByItsName() throws {
        let names = try starterNames()
        let map = try map()
        #expect(Set(map.exercises.map(\.id)) == Set(names.keys))
        for entry in map.exercises {
            #expect(names[entry.id] == entry.name, "exercise \(entry.id)")
            #expect(!entry.primary.isEmpty, "\(entry.name)")
            #expect(Set(entry.primary).isDisjoint(with: entry.secondary), "\(entry.name)")
        }
        #expect(ExerciseMuscles.byID.count == names.count)
    }

    @Test func everyMuscleIsOnTheMap() throws {
        let map = try map()
        let shown = Set((map.muscles(.front) + map.muscles(.back)).map(\.0))
        #expect(shown == Set(Muscle.allCases))
        #expect(map.body.allSatisfy { $0.count >= 8 && ($0.count - 2) % 6 == 0 })
    }

    @Test func theAnimationsMusclesAreAmongTheMaps() {
        for (id, motion) in ExerciseMotions.byID {
            guard let work = ExerciseMuscles.byID[Int64(id)] else {
                Issue.record("\(motion.name) has no muscles")
                continue
            }
            #expect(motion.muscles.isSubset(of: Set(work.primary + work.secondary)), "\(motion.name)")
        }
    }

    @Test func peoplesOwnExercisesShowTheirGroup() {
        for group in MuscleGroup.allCases {
            #expect(!group.muscles.isEmpty, "\(group)")
        }
        let own = Exercise(id: 9_999, name: "Cable Press", target: "Chest")
        #expect(ExerciseMuscles.work(for: own) == MuscleWork(primary: [.chest], secondary: []))
        #expect(ExerciseMuscles.work(for: Exercise(id: 9_998, name: "Odd", target: "Elsewhere")) == nil)
    }

    @Test func namesAreListedLikeASentence() {
        #expect(MuscleWork.list([.glutes, .hamstrings, .lowerBack]) == "Glutes, hamstrings, lower back")
    }

    @MainActor @Test func theMapDrawsItsMuscles() throws {
        let view = MuscleMapView(work: MuscleWork(primary: [.chest], secondary: [.triceps]))
            .frame(width: 370)
            .environment(\.colorScheme, .light)
        let image = try #require(ImageRenderer(content: view).cgImage)
        // Pixels near olive, #63611E, are the chest and the swatch beside its name.
        #expect(Self.pixels(image, near: (0x63, 0x61, 0x1E)) > 150)
    }

    private static func pixels(_ image: CGImage, near color: (Int, Int, Int)) -> Int {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return stride(from: 0, to: data.count, by: 4).reduce(0) { count, i in
            let close = abs(Int(data[i]) - color.0) < 12 && abs(Int(data[i + 1]) - color.1) < 12
                && abs(Int(data[i + 2]) - color.2) < 12 && data[i + 3] > 200
            return count + (close ? 1 : 0)
        }
    }
}
