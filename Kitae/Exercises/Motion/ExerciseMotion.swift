// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Muscles the figure can show in olive.
nonisolated enum Muscle: String, Decodable, Sendable, CaseIterable {
    case quads, hamstrings, glutes, calves
    case chest, abs, obliques, lats, traps, lowerBack
    case frontDelts, sideDelts, rearDelts, biceps, triceps, forearms
}

/// Something the figure holds or uses, or a piece of a bench or machine.
nonisolated struct Gear: Decodable, Sendable, Equatable {
    nonisolated enum Kind: String, Decodable, Sendable {
        /// A plate seen end-on, in the hands or across the shoulders (`on` "back").
        case barbell
        /// A barbell with smaller plates.
        case ezbar
        case dumbbells
        /// A bench, seat or pad: its top edge from `from` to `to`, `thick` deep, with legs down to the
        /// floor at the x of each of `legs`. `front` pads are drawn over the body, under the near arm.
        case pad
        /// A frame member from `from` to `to`, `width` wide.
        case post
        /// A cable from a pulley at `from` to the hands (or `on`), ending in a `handle`:
        /// "bar", "rope", "single" or "none". `stack` draws the weight stack under the pulley.
        case cable
        /// A pull-up bar seen end-on at `at`.
        case bar
        /// A machine's foam roller, at `at` or following the body (`on`).
        case roller
        /// A machine's handle in the hands.
        case handle
    }

    var kind: Kind
    /// The part of the body it follows: "hands", "back", "ankle", "shin", "thigh", "hips" or "chest".
    var on: String?
    var from: Vec?
    var to: Vec?
    var at: Vec?
    var thick: Double
    var legs: [Double]
    var width: Double
    var handle: String
    var stack: Bool
    /// Dumbbells seen side-on, for a neutral grip.
    var profile: Bool
    /// One dumbbell hanging from both hands, as in overhead extensions.
    var hang: Bool
    /// Only in the near hand.
    var one: Bool
    var radius: Double?
    var front: Bool

    nonisolated private enum Keys: String, CodingKey {
        case kind, on, from, to, at, thick, legs, width, handle, stack, profile, hang, one, radius, front
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        on = try c.decodeIfPresent(String.self, forKey: .on)
        from = try c.decodeIfPresent(Vec.self, forKey: .from)
        to = try c.decodeIfPresent(Vec.self, forKey: .to)
        at = try c.decodeIfPresent(Vec.self, forKey: .at)
        thick = try c.decodeIfPresent(Double.self, forKey: .thick) ?? 8
        legs = try c.decodeIfPresent([Double].self, forKey: .legs) ?? []
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 4
        handle = try c.decodeIfPresent(String.self, forKey: .handle) ?? "bar"
        stack = try c.decodeIfPresent(Bool.self, forKey: .stack) ?? false
        profile = try c.decodeIfPresent(Bool.self, forKey: .profile) ?? false
        hang = try c.decodeIfPresent(Bool.self, forKey: .hang) ?? false
        one = try c.decodeIfPresent(Bool.self, forKey: .one) ?? false
        radius = try c.decodeIfPresent(Double.self, forKey: .radius)
        front = try c.decodeIfPresent(Bool.self, forKey: .front) ?? false
    }
}

/// An exercise's animation: two keyframes of the figure, the muscles it works and the gear it
/// uses, read from ExerciseMotions.json. They're keyed by the ids of the exercises Kitae starts
/// with, which are the same as Kitae for Android's and are never given to another exercise.
/// scripts/motions makes the file and draws it as pictures for checking.
nonisolated struct ExerciseMotion: Decodable, Sendable, Identifiable {
    /// The id of the exercise it shows.
    var id: Int
    /// The exercise's name as Kitae starts with it, to make the file easier to read.
    var name: String
    var gear: [Gear]
    var muscles: Set<Muscle>
    /// The ends of the hold at the start, the move to the end, the hold at the end and the
    /// move back, as fractions of a loop.
    var timing: [Double]
    /// Length of one loop.
    var seconds: Double
    /// Moves the figure sideways so it sits in the middle of its card.
    var shift: Double
    /// Draws the figure smaller (below 1) for exercises that need more room, such as pull-ups.
    var zoom: Double
    /// Middle and half width of the shadow on the floor.
    var shadow: Vec
    var shadowWidth: Double
    var from: FigurePose
    var to: FigurePose

    nonisolated private enum Keys: String, CodingKey {
        case id, name, gear, muscles, timing, seconds, shift, zoom, shadow, shadowWidth, from, to
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        gear = try c.decodeIfPresent([Gear].self, forKey: .gear) ?? []
        muscles = Set(try c.decodeIfPresent([Muscle].self, forKey: .muscles) ?? [])
        timing = try c.decodeIfPresent([Double].self, forKey: .timing) ?? [0.08, 0.5, 0.58, 0.96]
        seconds = try c.decodeIfPresent(Double.self, forKey: .seconds) ?? 2.4
        shift = try c.decodeIfPresent(Double.self, forKey: .shift) ?? 0
        zoom = try c.decodeIfPresent(Double.self, forKey: .zoom) ?? 1
        shadow = try c.decodeIfPresent(Vec.self, forKey: .shadow) ?? Vec(4, 0)
        shadowWidth = try c.decodeIfPresent(Double.self, forKey: .shadowWidth) ?? 40
        from = try c.decode(FigurePose.self, forKey: .from)
        to = try c.decode(FigurePose.self, forKey: .to)
    }

    /// The pose `t` of the way through a loop (0…1).
    func pose(at t: Double) -> FigurePose {
        FigurePose.lerp(from, to, FigureMath.phase(t, timing))
    }

    func gear(_ kind: Gear.Kind) -> [Gear] {
        gear.filter { $0.kind == kind }
    }
}

nonisolated enum ExerciseMotions {
    /// The animations, by exercise id.
    static let byID: [Int: ExerciseMotion] = {
        guard let url = Bundle.main.url(forResource: "ExerciseMotions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? decode(data) else { return [:] }
        return Dictionary(list.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }()

    static func decode(_ data: Data) throws -> [ExerciseMotion] {
        try JSONDecoder().decode([ExerciseMotion].self, from: data)
    }

    /// The animation of an exercise, if it has one.
    static func motion(for id: Int64) -> ExerciseMotion? {
        byID[Int(id)]
    }
}
