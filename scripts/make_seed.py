#!/usr/bin/env python3
# Kitae for iPhone
# SPDX-License-Identifier: GPL-3.0-or-later
"""Writes Kitae/Database/Seed.json from Kitae for Android's starter database.

Kitae for Android ships its exercises and its starter plan in app/src/main/assets/kenko.db.
Kitae for iPhone starts from the same exercises, with the same ids, and the same plan, so
both apps begin alike. The plan's description is left out: it's text from Kenko, and
Kitae for iPhone doesn't include Kenko's work. Run this again when the Android app's
starter data changes:

    python3 scripts/make_seed.py path/to/kitae/app/src/main/assets/kenko.db
"""

import json
import sqlite3
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row

    exercises = []
    for row in db.execute("SELECT * FROM exercises ORDER BY id"):
        exercise = {
            "id": row["id"],
            "name": row["name"],
            "target": row["target"],
            "isIsometric": bool(row["isIsometric"]),
        }
        for column in ("reference", "restSeconds", "instructions"):
            if row[column] is not None:
                exercise[column] = row[column]
        exercises.append(exercise)

    plans = []
    for plan in db.execute("SELECT * FROM plans ORDER BY id"):
        days = []
        routines = db.execute(
            "SELECT * FROM routines WHERE planId = ? ORDER BY position, id", (plan["id"],)
        ).fetchall()
        for routine in routines:
            day_exercises = []
            slots = db.execute(
                "SELECT * FROM routine_exercises WHERE routineId = ? ORDER BY position, id",
                (routine["id"],),
            ).fetchall()
            for slot in slots:
                sets = []
                planned = db.execute(
                    "SELECT * FROM routine_sets WHERE routineExerciseId = ? ORDER BY position, id",
                    (slot["id"],),
                ).fetchall()
                for planned_set in planned:
                    entry = {
                        "reps": planned_set["reps"],
                        "weight": planned_set["weight"],
                        "type": planned_set["type"],
                    }
                    if planned_set["restSeconds"] is not None:
                        entry["restSeconds"] = planned_set["restSeconds"]
                    sets.append(entry)
                day_exercises.append({"exercise": slot["exerciseId"], "sets": sets})
            days.append({"name": routine["name"], "exercises": day_exercises})
        entry = {"name": plan["name"]}
        for column in ("difficulty", "focus", "equipment", "time"):
            if plan[column] is not None:
                entry[column] = plan[column]
        entry["days"] = days
        plans.append(entry)

    out = Path(__file__).resolve().parent.parent / "Kitae" / "Database" / "Seed.json"
    out.write_text(json.dumps({"exercises": exercises, "plans": plans}, indent=1, ensure_ascii=False) + "\n")
    print(f"{out}: {len(exercises)} exercises, {len(plans)} plans")


if __name__ == "__main__":
    main()
