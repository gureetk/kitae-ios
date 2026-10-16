// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI

/// The figure's colours, made where the environment is known and handed to the painter.
nonisolated struct FigurePalette: Sendable {
    var body: Color
    var far: Color
    var muscle: Color
    var muscleFar: Color
    var gear: Color
    var gearFace: Color
    var prop: Color
    var shadow: Color
}

/// Draws an exercise's figure, its worked muscles and its gear into a Canvas, back to front:
/// the shadow, frames and weight stacks, the far arm and leg, benches and seats, the body and
/// head, pads in front of it, cables and bars, the near leg and arm, and what the near hand holds.
/// scripts/motions/motion.js draws the same way, for checking poses as pictures.
nonisolated struct FigurePainter: Sendable {
    let motion: ExerciseMotion
    let palette: FigurePalette

    /// The figure `t` of the way through a loop (0…1), standing on the bottom of `size`.
    func draw(at t: Double, in context: inout GraphicsContext, size: CGSize) {
        place(&context, size)
        draw(Figure(motion.pose(at: t)), in: &context)
    }

    /// For Reduce Motion: the end pose, with the start pose faintly behind it.
    func drawStill(in context: inout GraphicsContext, size: CGSize) {
        place(&context, size)
        var ghost = context
        ghost.opacity = 0.4
        ghost.drawLayer { layer in draw(Figure(motion.from), in: &layer) }
        draw(Figure(motion.to), in: &context)
    }

    private func place(_ context: inout GraphicsContext, _ size: CGSize) {
        let scale = min(1.15, (size.height - 34) / 190) * motion.zoom
        context.translateBy(x: size.width / 2 + motion.shift * scale, y: size.height - 20)
        context.scaleBy(x: scale, y: scale)
    }

    func draw(_ f: Figure, in context: inout GraphicsContext) {
        let c = palette
        let muscles = motion.muscles
        let farArm = ArmShape(f.farArm), nearArm = ArmShape(f.nearArm)

        func fill(_ path: Path, _ color: Color) {
            context.fill(path, with: .color(color))
        }
        func fillInside(_ clip: Path, _ path: Path, _ color: Color) {
            var clipped = context
            clipped.clip(to: clip)
            clipped.fill(path, with: .color(color))
        }
        func leg(_ l: LegShape, _ body: Color, _ muscle: Color) {
            fill(l.thigh, body)
            fill(l.shin, body)
            fill(l.foot, body)
            if muscles.contains(.quads) { fillInside(l.thigh, l.quads, muscle) }
            if muscles.contains(.hamstrings) { fillInside(l.thigh, l.hamstrings, muscle) }
            if muscles.contains(.calves) { fillInside(l.shin, l.calves, muscle) }
        }
        func arm(_ a: ArmShape, _ body: Color, _ muscle: Color) {
            fill(a.upper, body)
            fill(a.forearm, body)
            fill(a.hand, body)
            let cap = FigureShapes.union(a.upper, FigureShapes.circle(a.arm.shoulder, 7.2))
            if muscles.contains(.biceps) { fillInside(a.upper, a.biceps, muscle) }
            if muscles.contains(.triceps) { fillInside(a.upper, a.triceps, muscle) }
            if muscles.contains(.forearms) { fillInside(a.forearm, a.forearms, muscle) }
            if muscles.contains(.sideDelts) { fillInside(cap, a.delts(0), muscle) }
            if muscles.contains(.frontDelts) { fillInside(cap, a.delts(1), muscle) }
            if muscles.contains(.rearDelts) { fillInside(cap, a.delts(-1), muscle) }
        }
        func plate(_ at: Vec, _ r: Double) {
            fill(FigureShapes.circle(at, r), c.gear)
            fill(FigureShapes.circle(at, r * 0.735), c.gearFace)
            fill(FigureShapes.circle(at, r * 0.21), c.body)
        }
        func pad(_ g: Gear) {
            guard let from = g.from, let to = g.to else { return }
            let d = (to - from).unit, right = Vec(-d.y, d.x), h = g.thick / 2
            for x in g.legs {
                let k = (x - from.x) / (to.x - from.x == 0 ? 1 : to.x - from.x)
                let top = Vec.lerp(from, to, k) + right * h
                fill(FigureShapes.capsule(top, Vec(x, -2), 1.9, 1.9), c.prop)
                fill(FigureShapes.capsule(Vec(x - 8, -1.6), Vec(x + 8, -1.6), 1.6, 1.6), c.prop)
            }
            fill(FigureShapes.capsule(from + right * h, to + right * h, h, h), c.prop)
        }
        func dumbbell(_ a: ArmShape, near: Bool) {
            let g = a.grip
            let color = near ? c.gear : c.body
            if motion.gear(.dumbbells).contains(where: \.hang) {
                let top = g + Vec(0, 2)
                fill(FigureShapes.capsule(top, top + Vec(0, 15), 1.7, 1.7), color)
                for y in [0.0, 15] {
                    fill(FigureShapes.capsule(top + Vec(-7, y), top + Vec(7, y), 2.8, 2.8), color)
                }
            } else if motion.gear(.dumbbells).contains(where: \.profile) {
                let fd = (a.arm.wrist - a.arm.elbow).unit, axis = fd.front
                fill(FigureShapes.capsule(g - axis * 7, g + axis * 7, 1.7, 1.7), color)
                for k in [-8.0, 8] {
                    let end = g + axis * k
                    fill(FigureShapes.capsule(end - fd * 6.5, end + fd * 6.5, 2.8, 2.8), color)
                }
            } else if near {
                let at = g + Vec(1, 1)
                fill(FigureShapes.hexagon(at, 8.6, turned: 30), c.gear)
                fill(FigureShapes.hexagon(at, 6.0, turned: 30), c.gearFace)
                fill(FigureShapes.circle(at, 2.4), c.body)
            } else {
                fill(FigureShapes.hexagon(g + Vec(-1, -1), 8.6, turned: 30), c.body)
            }
        }
        // Points on the body that gear follows.
        func bodyPoint(_ name: String?) -> Vec {
            let l = f.nearLeg
            switch name {
            case "ankle": return l.ankle
            case "shin": return Vec.lerp(l.knee, l.ankle, 0.78)
            case "thigh": return Vec.lerp(l.hip, l.knee, 0.62) + (l.knee - l.hip).unit.front * 9
            case "hips": return f.torso(-2, 11)
            case "chest": return f.torso(36, 15)
            default: return nearArm.grip
            }
        }

        fill(FigureShapes.ellipse(motion.shadow, motion.shadowWidth, 3.4, turned: 0), c.shadow)

        // Behind everything: weight stacks and frame posts.
        for g in motion.gear(.cable) where g.stack {
            if let pulley = g.from {
                fill(FigureShapes.capsule(Vec(pulley.x, -3), pulley, 6.5, 6.5), c.prop)
            }
        }
        for g in motion.gear(.post) {
            if let from = g.from, let to = g.to {
                fill(FigureShapes.capsule(from, to, g.width / 2, g.width / 2), c.prop)
            }
        }

        // The far side, a little behind the near one.
        let dumbbells = motion.gear(.dumbbells)
        leg(LegShape(f.farLeg), c.far, c.muscleFar)
        arm(farArm, c.far, c.muscleFar)
        if !dumbbells.isEmpty, !dumbbells.contains(where: \.one) {
            dumbbell(farArm, near: false)
        }

        // Benches, seats and pads under the body.
        for g in motion.gear(.pad) where !g.front {
            pad(g)
        }

        // The body.
        let torso = torsoPath(f)
        fill(torso, c.body)
        if muscles.contains(.glutes) {
            fillInside(torso, FigureShapes.ellipse(f.torso(-1.5, -8.5), 8.5, 10.5, turned: f.turn(at: -1.5)), c.muscle)
        }
        if muscles.contains(.chest) {
            fillInside(torso, FigureShapes.ellipse(f.torso(37, 8.5), 6.5, 9, turned: f.turn(at: 37)), c.muscle)
        }
        if muscles.contains(.abs) {
            fillInside(torso, FigureShapes.capsule(f.torso(4, 5.8), f.torso(27, 8.5), 3.4, 3.4), c.muscle)
        }
        if muscles.contains(.obliques) {
            fillInside(torso, FigureShapes.ellipse(f.torso(14, 2), 4.5, 9, turned: f.turn(at: 14)), c.muscle)
        }
        if muscles.contains(.lats) {
            fillInside(torso, FigureShapes.ellipse(f.torso(33, -7.5), 4.5, 11, turned: f.turn(at: 33)), c.muscle)
        }
        if muscles.contains(.traps) {
            fillInside(torso, FigureShapes.ellipse(f.torso(50, -6), 5, 7, turned: f.turn(at: 50)), c.muscle)
        }
        if muscles.contains(.lowerBack) {
            fillInside(torso, FigureShapes.capsule(f.torso(6, -8), f.torso(26, -6.2), 2.8, 2.8), c.muscle)
        }

        // A barbell across the shoulders, seen a little from behind so the head stays clear.
        for g in motion.gear(.barbell) where g.on == "back" {
            let bar = f.torso(50, -9), at = bar + Vec(-9, 2.5)
            fill(FigureShapes.capsule(at, bar, 2.6, 2.6), c.gear)
            plate(at, g.radius ?? 17)
        }

        // Neck and head: a cranium and a jaw, so the face's direction reads.
        let headFront = Vec(-f.headDirection.y, f.headDirection.x)
        let turn = f.pose.head ?? (f.pose.lean + f.pose.curl)
        fill(FigureShapes.capsule(f.neckBase, f.neckTop, 5.6, 5.0), c.body)
        fill(FigureShapes.ellipse(f.head, 10.2, 11.6, turned: turn), c.body)
        fill(FigureShapes.ellipse(f.head + headFront * 3.2 - f.headDirection * 5.5, 7.4, 6.4, turned: turn), c.body)

        // Pads in front of the body, such as a preacher bench's, under the near arm.
        for g in motion.gear(.pad) where g.front {
            pad(g)
        }

        // Cables run to the middle of the body, behind the near arm; bars are gripped by it.
        for g in motion.gear(.cable) {
            guard let pulley = g.from else { continue }
            fill(FigureShapes.capsule(pulley, bodyPoint(g.on), 0.8, 0.8), c.gear)
            fill(FigureShapes.circle(pulley, 4.2), c.gear)
            fill(FigureShapes.circle(pulley, 1.7), c.prop)
        }
        for g in motion.gear(.bar) {
            if let at = g.at { fill(FigureShapes.circle(at, 3.6), c.gear) }
        }

        // The near side.
        leg(LegShape(f.nearLeg), c.body, c.muscle)
        arm(nearArm, c.body, c.muscle)

        // What the near hand holds, and machine pads in front of the legs.
        for g in motion.gear(.barbell) where g.on == nil || g.on == "hands" {
            plate(nearArm.grip, g.radius ?? 17)
        }
        for g in motion.gear(.ezbar) {
            plate(nearArm.grip, g.radius ?? 12.5)
        }
        if !dumbbells.isEmpty {
            dumbbell(nearArm, near: true)
        }
        for g in motion.gear(.cable) {
            guard let pulley = g.from else { continue }
            let end = bodyPoint(g.on)
            switch g.handle {
            case "rope":
                let d = (end - pulley).unit
                fill(FigureShapes.capsule(end - d * 9, end + d * 2, 2.2, 2.4), c.gear)
            case "single":
                fill(FigureShapes.circle(end, 3.6), c.gear)
                fill(FigureShapes.circle(end, 1.8), c.body)
            case "none":
                break
            default:
                fill(FigureShapes.circle(end, 3.2), c.gear)
            }
        }
        for g in motion.gear(.handle) {
            fill(FigureShapes.circle(bodyPoint(g.on), 3.4), c.gear)
        }
        for g in motion.gear(.roller) {
            let at = g.at ?? bodyPoint(g.on)
            fill(FigureShapes.circle(at, g.radius ?? 6.5), c.prop)
            fill(FigureShapes.circle(at, 2.2), c.gear)
        }
    }

    /// The torso's outline, from the hips up the front, over the shoulders and down the back.
    private func torsoPath(_ f: Figure) -> Path {
        let points: [(Double, Double)] = [
            (-7, 3), (2, 9), (16, 9), (29, 12.5), (41, 12.5), (50.5, 8),
            (54, -2), (51, -9.5), (39, -11.5), (24, -8.5), (11, -10.5), (0, -14.5), (-8.5, -9),
        ]
        return FigureShapes.outline(points.map { f.torso($0.0, $0.1) })
    }
}

/// A leg's parts and the muscles on them.
nonisolated private struct LegShape {
    let thigh: Path
    let shin: Path
    let foot: Path
    let quads: Path
    let hamstrings: Path
    let calves: Path

    init(_ l: Figure.Leg) {
        let td = (l.knee - l.hip).unit, sd = (l.ankle - l.knee).unit
        let midThigh = Vec.lerp(l.hip, l.knee, 0.42) + td.front * 1
        let calf = Vec.lerp(l.knee, l.ankle, 0.3) + sd.front * -1.8
        let turn = l.foot * .pi / 180
        let heel = l.ankle + Vec(-4.5, 2.9).rotated(by: turn)
        let toe = l.ankle + Vec(17, 4.2).rotated(by: turn)
        thigh = FigureShapes.union(FigureShapes.capsule(l.hip, midThigh, 10.4, 9.2),
                                   FigureShapes.capsule(midThigh, l.knee, 9.2, 6.6))
        shin = FigureShapes.union(FigureShapes.capsule(l.knee, calf, 6.6, 7.2),
                                  FigureShapes.capsule(calf, l.ankle, 7.2, 3.9))
        foot = FigureShapes.union(FigureShapes.capsule(heel, toe, 4.5, 3.2),
                                  FigureShapes.capsule(l.ankle, heel, 3.9, 4.5))
        quads = muscle(l.hip, l.knee, 10.4, 6.6, at: (0.12, 0.5, 0.9), widths: (0.55, 0.72, 0.7), side: 1)
        hamstrings = muscle(l.hip, l.knee, 10.4, 6.6, at: (0.14, 0.5, 0.88), widths: (0.5, 0.62, 0.55), side: -1)
        calves = muscle(l.knee, l.ankle, 7.0, 3.9, at: (0.08, 0.3, 0.62), widths: (0.62, 0.78, 0.5), side: -1)
    }
}

/// An arm's parts and the muscles on them.
nonisolated private struct ArmShape {
    let arm: Figure.Arm
    let upper: Path
    let forearm: Path
    let hand: Path
    /// Where the hand closes around a bar or handle.
    let grip: Vec
    let biceps: Path
    let triceps: Path
    let forearms: Path

    init(_ a: Figure.Arm) {
        arm = a
        let ud = (a.elbow - a.shoulder).unit, fd = (a.wrist - a.elbow).unit
        let fore = Vec.lerp(a.elbow, a.wrist, 0.3) + fd.front * 0.4
        grip = a.wrist + fd * (6.5 * max(a.scale, 0.8))
        upper = FigureShapes.capsule(a.shoulder, a.elbow, 6.8, 4.5)
        forearm = FigureShapes.union(FigureShapes.capsule(a.elbow, fore, 4.5, 5.0),
                                     FigureShapes.capsule(fore, a.wrist, 5.0, 3.3))
        hand = FigureShapes.capsule(a.wrist, grip, 3.6, 3.9)
        // The biceps grows a little as the elbow bends.
        let bent = acos(min(1, max(-1, ud.x * fd.x + ud.y * fd.y))) * 180 / .pi
        let k = min(1, bent / 130)
        biceps = muscle(a.shoulder, a.elbow, 6.8, 4.5, at: (0.2, 0.52, 0.86), widths: (0.55, 0.8 + 0.15 * k, 0.6), side: 1)
        triceps = muscle(a.shoulder, a.elbow, 6.8, 4.5, at: (0.16, 0.5, 0.86), widths: (0.55, 0.72, 0.58), side: -1)
        forearms = muscle(a.elbow, a.wrist, 5.0, 3.3, at: (0.1, 0.32, 0.75), widths: (0.8, 0.85, 0.6), side: 1)
    }

    /// The deltoid over the shoulder: its front (1), middle (0) or rear (-1).
    func delts(_ side: Double) -> Path {
        let w = side == 0 ? (1.0, 1.0, 0.65) : (0.62, 0.62, 0.45)
        return muscle(arm.shoulder, arm.elbow, 6.8, 4.5, at: (0, 0.17, 0.4), widths: w, side: side)
    }
}

/// A muscle hugging one side of a limb from `a` to `b` (radii `ra` and `rb`): thicker in its
/// middle than at its ends. `side` is 1 for the front of the limb, -1 for the back, 0 for both.
nonisolated private func muscle(_ a: Vec, _ b: Vec, _ ra: Double, _ rb: Double,
                                at k: (Double, Double, Double), widths w: (Double, Double, Double),
                                side: Double) -> Path {
    let out = (b - a).unit.front * side
    func point(_ t: Double, _ width: Double) -> (Vec, Double) {
        let r = FigureMath.lerp(ra, rb, t)
        return (Vec.lerp(a, b, t) + out * (r - r * width - 0.1), r * width)
    }
    let (p1, r1) = point(k.0, w.0), (p2, r2) = point(k.1, w.1), (p3, r3) = point(k.2, w.2)
    return FigureShapes.union(FigureShapes.capsule(p1, p2, r1, r2), FigureShapes.capsule(p2, p3, r2, r3))
}
