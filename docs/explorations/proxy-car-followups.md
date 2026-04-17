# Proxy Car Controller Follow-Ups

The proxy-car controller makes the prototype stable enough to support a deliberate polish pass. This note collects future-facing work that should stay out of the runtime controller for now.

---

## 1. Smoke, Audio, and Model Hooks

The controller now exposes motion states that are worth turning into feedback: grounded, drifting, landing, uphill load, speed-cap pressure, and air recovery. That makes a cleaner juice pass possible without adding more physics complexity.

Useful follow-ups:
- Build smoke that varies by surface and drift intensity instead of one generic puff.
- Add audio hooks for skid, landing, boost, suspension load, and harsh surface contact.
- Keep those hooks state-driven and event-driven, so the effect layer follows the controller instead of sampling raw physics everywhere.
- Look for a car body and wheel setup that reads well with the fake lean, steering, and proxy roll separation.

Constraint:
- Keep the asset style toy-like and readable. The controller should feel convincing on its own; the visuals only need to reinforce that language.

---

## 2. Optional Asset Sourcing

If we decide to source rather than build everything in-house, the safest target is a simple, readable arcade car kit rather than a realistic vehicle pack.

What to prefer:
- Chunky silhouettes with clear wheel read and a strong body outline.
- Smoke or skid assets that can be recolored and layered by surface type.
- Sound packs with short, punchy transients over long realistic recordings.

What to avoid:
- Highly realistic suspension rigs that fight the fake lean.
- Busy body geometry that hides wheel steer or makes the proxy/controller separation obvious in a bad way.
- Effects that depend on a perfect simulation match.

Working assumption:
- Any sourced asset should be easy to retarget into the controller's existing state model rather than forcing the controller to become more realistic.

---

## 3. Car-Feel Tuning Experiments

The proxy architecture makes it easier to tune feel in separate layers instead of treating driving as one opaque physics problem.

Useful experiments:
- Drift entry and recovery curves: test whether the car should snap in faster than it snaps out.
- Uphill traction and throttle assist: check how much extra climb help is needed before the car feels sticky instead of playful.
- Jump behavior: tune air steering, landing forgiveness, and whether the car preserves heading or re-centers gradually.
- Body response: exaggerate pitch, roll, and steering lean to make speed feel juicier without destabilizing the drive model.
- Surface response: confirm that sand and grass slow the car meaningfully while still letting the player recover quickly.

Likely direction:
- Keep the controller forgiving by default, then layer stronger feedback when the player is already making an interesting choice, such as committing to a drift or pushing over a ramp.

---

## 4. Future Tile and Hazard Ideas

The new handling model supports track pieces that were awkward before because the car can now tolerate more slope, more drift commitment, and more airborne variance.

Ideas that fit the new controller:
- Crest-and-dip tiles that create readable jumps without requiring perfect alignment.
- Longer drift-friendly corners that reward holding a stable slide through a full segment.
- Narrow bridge or lane-split tiles that make the proxy's stability matter without punishing landing too hard.
- Surface-transition tiles that move between tarmac, sand, and grass in ways the player can feel immediately.
- Hazards that change line choice more than raw speed, such as lateral nudges, soft funneling, or temporary grip changes.

Best future pieces:
- Support a controlled jump.
- Or create a decision about line choice while the car is drifting.

Anything that only adds friction without adding a new decision is probably the wrong direction.

---

## 5. Validation Ideas

Future juice work should be validated against behavior, not just screenshots or asset quality.

Things worth checking:
- Flat-map playability with no random tipping.
- Figure-eight / crossing-track stability with bridge and underpass cases.
- Controlled jump recovery: no self-righting snap that kills the airborne feel.
- Drift readability: easy initiation, forgiving exit, and clear visual lean.
- Surface balance: tarmac should stay responsive; sand and grass should slow the car without stalling it.
- Collision-owner resolution should still work when the car is represented by a proxy child body.

Good validation formats:
- A short headless smoke test for controller regression.
- One live playtest pass on flat and hilly tracks.
- A targetted drift/jump pass after any smoke or audio change, because those assets tend to hide handling regressions.

---

## Working Rule

Treat the proxy controller as a platform, not just a fix. If a future asset, tuning pass, tile, or hazard does not make the car feel more readable, more toy-like, or more intentional, it probably belongs lower on the list.
