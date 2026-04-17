# Car Juice Validation Notes

This is a lightweight checklist for future polish passes on the proxy-car controller. It is intentionally separate from the implementation so it can grow without forcing code changes.

---

## What A Future Pass Should Prove

Any smoke, audio, visual lean, or new tile should make at least one of these better:
- The car feels easier to understand at speed.
- Drift and jump states are easier to read.
- Surface changes are obvious without being punishing.
- The car stays playful on flat ground and on slopes.

If a change does not improve one of those, it should probably not ship.

---

## Quick Review Checklist

- Grounded driving stays stable on flat maps.
- The car climbs normal slopes without stalling.
- Airborne motion stays controllable and does not self-correct too aggressively.
- Drift feedback rewards commitment instead of making the player babysit the slide.
- Smoke and audio line up with the actual motion state, not with a guessed speed bucket.
- Visual lean, wheel steer, and body roll remain readable from a top-down or chase camera.

---

## Asset Sourcing Checklist

If we source smoke, audio, or a vehicle model later, prioritize:
- Simple silhouettes with strong contrast against the track.
- Effects that can be recolored or intensity-scaled per surface.
- Short, arcade-friendly sounds over realism-heavy recordings.
- Assets that tolerate fake lean and proxy-driven motion without exposing the trick.

Avoid assets that require:
- Detailed suspension simulation.
- Highly specific wheel geometry to read correctly.
- New controller behavior just to make the asset look right.

---

## Tile Prototyping Checklist

Future tiles should be checked against the controller's current strengths:
- Can the car enter and exit the tile with a small steering correction?
- Does the tile create a decision, not just extra friction?
- Does the slope or jump remain readable when the camera is following behind?
- Does the piece still work if the player is already drifting?

Good candidate tile families:
- Crest-and-dip jump sections.
- Long drift corners with a visible reward line.
- Bridge or split-path tiles with forgiving recovery space.
- Surface transition strips that make traction changes obvious.

---

## Validation Formats

Recommended future validation passes:
- One headless regression check for controller stability.
- One live flat-track feel test.
- One live slope and jump test.
- One drift-heavy circuit test with audio and smoke enabled.

This should stay small and repeatable. The goal is to catch feel regressions early, not to build a full testing harness for every future idea.
