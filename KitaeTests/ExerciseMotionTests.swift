// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Kitae

/// The exercise animations: that they load, match the starter exercises and hold together.
struct ExerciseMotionTests {
    /// Starter exercises that move out to the sides, waiting for a front-facing figure.
    private static let frontFacing: Set<Int> = [8]

    private func motions() throws -> [ExerciseMotion] {
        let url = try #require(Bundle.main.url(forResource: "ExerciseMotions", withExtension: "json"))
        return try ExerciseMotions.decode(Data(contentsOf: url))
    }

    /// The starter exercises' names by id, and the exercises of the starter plan, from Seed.json.
    private func seed() throws -> (names: [Int: String], planned: Set<Int>) {
        let url = try #require(Bundle.main.url(forResource: "Seed", withExtension: "json"))
        let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let exercises = try #require(json["exercises"] as? [[String: Any]])
        var names: [Int: String] = [:]
        for exercise in exercises {
            names[try #require(exercise["id"] as? Int)] = try #require(exercise["name"] as? String)
        }
        var planned: Set<Int> = []
        for plan in try #require(json["plans"] as? [[String: Any]]) {
            for day in try #require(plan["days"] as? [[String: Any]]) {
                for item in try #require(day["exercises"] as? [[String: Any]]) {
                    planned.insert(try #require(item["exercise"] as? Int))
                }
            }
        }
        return (names, planned)
    }

    @Test func motionsLoadFromTheApp() {
        #expect(!ExerciseMotions.byID.isEmpty)
    }

    @Test func eachMotionShowsAStarterExerciseByItsName() throws {
        let names = try seed().names
        let list = try motions()
        #expect(Set(list.map(\.id)).count == list.count)
        for motion in list {
            #expect(names[motion.id] == motion.name, "motion \(motion.id)")
        }
    }

    @Test func theStarterPlanIsCovered() throws {
        let covered = Set(try motions().map(\.id))
        let missing = try seed().planned.subtracting(covered).subtracting(Self.frontFacing)
        #expect(missing.isEmpty, "no motion for \(missing.sorted())")
    }

    @Test func keyframesCanBeBlended() throws {
        for motion in try motions() {
            let from = motion.from, to = motion.to
            #expect(from.arm.kind == to.arm.kind, "\(motion.name): arm")
            #expect(from.farArm?.kind == to.farArm?.kind, "\(motion.name): far arm")
            #expect((from.thigh == nil) == (to.thigh == nil), "\(motion.name): legs")
            #expect((from.shin == nil) == (to.shin == nil), "\(motion.name): shins")
            #expect(motion.timing.count == 4, "\(motion.name): timing")
            #expect(motion.timing == motion.timing.sorted() && motion.timing.allSatisfy { (0...1).contains($0) },
                    "\(motion.name): timing")
            #expect(motion.seconds > 0 && (0.5...1.2).contains(motion.zoom), "\(motion.name): loop")
        }
    }

    @Test func limbsKeepTheirLengthsAndStayAboveTheFloor() throws {
        for motion in try motions() {
            for step in 0...20 {
                let pose = motion.pose(at: Double(step) / 20)
                let figure = Figure(pose)
                for leg in [figure.nearLeg, figure.farLeg] {
                    #expect(abs((leg.knee - leg.hip).length - FigureBody.thigh) < 0.01, "\(motion.name): thigh")
                    #expect(abs((leg.ankle - leg.knee).length - FigureBody.shin) < 0.01, "\(motion.name): shin")
                    #expect(leg.knee.y <= 0 && leg.ankle.y <= 0, "\(motion.name): leg below the floor")
                }
                for arm in [figure.nearArm, figure.farArm] {
                    let forearm = (arm.wrist - arm.elbow).length
                    #expect(abs(forearm - FigureBody.forearm * arm.scale) < 0.01, "\(motion.name): forearm")
                    #expect(arm.wrist.y <= 0 && arm.elbow.y <= 0, "\(motion.name): arm below the floor")
                }
                #expect(figure.head.y < 0 && pose.hip.y < 0, "\(motion.name): body below the floor")
            }
        }
    }

    @Test func blendingHalfwayMixesBothKeyframes() {
        let a = FigurePose(hip: Vec(0, -100), lean: 0, arm: .swing(upper: 0, bend: 0, upperLength: 1))
        let b = FigurePose(hip: Vec(-30, -60), lean: 40, curl: 10, arm: .swing(upper: 20, bend: 120, upperLength: 0.5))
        let mid = FigurePose.lerp(a, b, 0.5)
        #expect(mid.hip == Vec(-15, -80))
        #expect(mid.lean == 20 && mid.curl == 5)
        #expect(mid.arm == .swing(upper: 10, bend: 60, upperLength: 0.75))
    }

    @Test func aLoopHoldsThenMovesThenHolds() {
        let k = [0.1, 0.5, 0.6, 0.9]
        #expect(FigureMath.phase(0.05, k) == 0)
        #expect(abs(FigureMath.phase(0.3, k) - 0.5) < 1e-9)
        #expect(FigureMath.phase(0.55, k) == 1)
        #expect(FigureMath.phase(0.95, k) == 0)
    }
}
