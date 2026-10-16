# Exercise animations

`Kitae/Exercises/Motion/ExerciseMotions.json` holds each exercise's animation: its start and end
poses, the gear it uses and the muscles it works, keyed by the starter exercises' ids. `make.js`
writes it (edit the poses there, not in the JSON). `sheet.js` and `zoom.js`
draw it as pictures, so poses can be checked without building the app. They draw with
`motion.js`, which matches `FigureRig.swift` and `FigurePainter.swift` step for step: a change to
one needs the same change in the other.

    npm install          # only needed for the pictures
    node make.js
    node sheet.js ../../Kitae/Exercises/Motion/ExerciseMotions.json sheet.png light 21,22
    node zoom.js ../../Kitae/Exercises/Motion/ExerciseMotions.json zoom.png 21:0 21:0.55 21:still

`sheet.js` draws a row per exercise (all of them, or the ids given): four moments of the loop and
the Reduce Motion picture, in `light` or `dark`. `zoom.js` draws chosen moments, `id:t` with `t`
from 0 to 1 or `still`, at twice the size.

## Poses

The figure faces right, 190 units tall, with the floor at y = 0 and y growing downward. A pose
gives the hip, the spine's `lean` (0 upright, 90 face down, -90 face up), and either an ankle the
leg reaches for or `thigh` and `shin` angles (0 up, 90 forward, 180 down). Arms either `swing`
(`upper` degrees forward from hanging and `bend` at the elbow) or reach for a `hand` point, in the
scene or on the body (`on: "torso"`: along the spine, then out the front). `scale` and
`upperLength` shorten arms that point toward the viewer. `curl` bends the spine above the waist
and `shrug` lifts the shoulders. The far arm and leg copy the near ones a little behind them,
unless `farArm`, `farAnkle` or `farThigh` and `farShin` say otherwise.

Exercises that move out to the sides, such as lateral raises, need a front-facing figure, which
doesn't exist yet.
