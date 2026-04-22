# Overlap — Game Design

## Core Loop

Race laps on a circuit under a timer. Each completed lap increases a multiplier, making every subsequent lap more valuable. Between rounds, spend earnings to place beneficial elements on the track, draft and place hazards, and watch the track mutate longer. The run ends when the track has grown too long and hazardous to sustain earnings.

### Drive Phase

- Lap-based multiplier: starts at x1, +1 per lap. Collectibles scale with it.
- Timer pressure creates "one more lap" greed.
- Track contains both player-placed positives and negatives.

### Pit Stop Phase (between rounds)

1. **Buy positives** — spend earnings on beneficial items such as boost pads and timer-extension tokens. Timer-extension cost scales per purchase, and new shop items land as they prove fun in testing.
2. **Draft a hazard** — pick 1 of 2 offered hazards (the lesser evil) and place it on the track.
3. **Track mutation** (every N rounds) — circuit grows longer. Laps take more time, multiplier grows slower, earnings pressure increases.

### Run Arc

Round 1 is gentle: simple track, generous timer, no hazards. Difficulty escalates through player choices. Soft fail state — earnings collapse, not a hard game over. 10-20 minute runs. Restarting should feel painless.

## Design Principles

1. **Driving feel first.** The car must feel excellent before anything else matters.
2. **Pressure through escalation.** Readable hazards and harder asks, not stat growth.
3. **Upgrades change gameplay, not stats.** "Boost ability" good, "+5% speed" bad.
4. **Player-driven difficulty.** You placed the hazards. You chose which negative.
5. **Prototype before committing.** No mechanic is settled until playtested.
6. **Juice is handling work, not polish.** Screen shake, particles, sound are part of how the car feels.
7. **Build physics toward fun, not down from realism.** Simple fake forces over simulation.

## Driving Feel

- Simple arcade physics. No tire simulation, no slip angle math.
- Drift should never feel like a punishment. Exact drift reward model is open — discover through playtesting.
- Camera should keep the car readable and never let orientation become confusing. Exact perspective is being explored.
- Constant acceleration. Rarely force the player to fully stop.
- Responsive instantly — no input lag, no sluggish turning.

## Car Classes (future — design around it, don't build yet)

4 vehicle types with 20-30% parameter variance. Each takes different racing lines.

| Class | Identity | Feel |
|-------|----------|------|
| Speedster | Glass cannon | High speed, low grip, fragile |
| Tank | Battering ram | Slow, high grip, heavy |
| Drifter | Style machine | Medium speed, low drift threshold |
| Balanced | Jack of all trades | No extremes, the learning car |

Use exported Resource scripts for tuning so classes are easy to add.

## What Not To Do

- Don't build realistic physics. Build fun physics.
- Don't add combat, opponents, or weapons yet.
- Don't procedurally generate tracks. Every track piece is hand-authored.
- Don't add meta-progression. One run needs to be fun first.
- Don't over-engineer architecture. Get it playable.

## Inspirations

Balatro (multiplier greed), Turbo Sliders (top-down feel), Vampire Survivors (roguelite structure), Hades (run pacing), Burnout (class differentiation).

---

# Design Toolkit

Generic design frameworks adapted to Overlap's context. Pull from these when making a design decision; ignore the parts that don't apply. **The toolkit serves the principles above, not the reverse.**

## 1. Feel: Chain and Diagnostic

> Feel is the priority. Feel is also not yet found — `car/car_stats.gd` holds working-in-progress defaults, not a validated target.

Every input travels through a chain. When feel is "off," identify which link is broken *before* adjusting numbers.

```
Input → Heading → Velocity → Visual Pose → Camera → Audio → World Response
```

**Timing gates:** Input → Heading → Velocity within one frame (≤16ms). Visual pose and camera within 2–3 frames. Audio within one frame of the triggering tick. Slower = laggy.

**Three feedback layers must agree on every action:**
- Mechanical (game state changes) · Audiovisual (sensory response) · Emotional (what the player feels)
- Misalignment is felt before it's named: big visual + no mechanical = "all flash"; mechanical + no audiovisual = "didn't feel like I hit them."

### Driving-feel diagnostic

| Playtester complaint | Likely link | First tuning move |
|---|---|---|
| "laggy" | Input | Verify `_physics_process` gates input, not `_process` |
| "twitchy / over-responsive" | Heading | Reduce `turn_speed` or `steering_response`; raise `speed_for_full_turn` |
| "sluggish / won't turn" | Heading | Raise `turn_speed`; lower `speed_for_full_turn` |
| "rails / never slides" | Velocity | Lower `grip`; lower `drift_threshold` |
| "boat / won't stop sliding" | Velocity | Raise `grip`; shorten `drift_grip_recovery_duration` |
| "drift entry weird" | Velocity | Check `drift_threshold` AND `drift_min_speed` — entry needs both slip and speed |
| "drift exit snaps" | Velocity | Lengthen `drift_grip_recovery_duration` |
| "floaty" | Velocity + Pose | Raise `linear_drag` and `ground_stick_force` |
| "grindy / won't coast" | Velocity | Lower `linear_drag` |
| "lost the car on screen" | Camera | Camera lead + zoom curve; never let the car leave a safe zone |
| "hits don't feel like hits" | Audio + World | Add screen shake, particle burst, audio layer |
| "flat / forgettable" | World | Surface cues, drift smoke, camera shake, audio layering |

**Key move:** before changing numbers, identify which link broke. Tuning `grip` when the complaint is "laggy" just produces a new kind of wrong.

### Assists are the feel, not cheating

Speed-scaled steering, counter-yaw on drift exit, grip lerps, surface multipliers — these are not compensations for a bad simulation. They ARE the feel. Budget as much time on this "assists layer" as on the physics core.

### Tuning in discovery mode

Feel is still being *discovered*, not refined. Expect ≥2× knob moves to find the right neighborhood, then 5–20% to dial in. Change one knob at a time. Drive a full lap on both controllers (`SphereCar`, `PhysicsCar`) after each change. Revert if unsure.

### Current state of feel systems

- **`CarAudio`** — engine (pitch/volume on throttle), drift (loop on drift-start/end), crash (on body contact with speed threshold). Surface audio does not exist.
- **`DriftFeedback`** — rear-wheel smoke, on/off only. Not strength-scaled.
- **Surface transitions** — change handling (`grip`, drag) with no audio/visual cue. This is a known gap.

### Silent surfaces are an anti-pattern

If handling changes on a surface boundary with no cue, the car feels possessed. Closing that gap is a live design task.

---

## 2. Balance: Cost Curves and Dominant Strategy

Every hazard and positive should sit on a consistent curve of cost vs. impact. When one item dominates the pick rate, alternatives are undertuned or this item is overtuned.

**Overlap-specific:** the draft offers 1-of-2. Both options must be viable against *some* current-track context, or the draft becomes an obvious pick, not a decision. Category filtering (`LINE_TAX` vs `HARD_REROUTE`) already enforces some balance — keep that invariant.

**Dominant-strategy symptoms:**
- One hazard picked > 50% when offered
- One positive is a must-buy regardless of run context
- Players converge on the same build across skill levels
- Drift is always better than cornering (drift ate the game)

**Tuning workflow:** reach for cost curves and payoff matrices *when a symptom appears*. Don't build spreadsheets preemptively — that violates principle 5.

---

## 3. Motivation: What Makes Players Want to Re-run

Three intrinsic needs predict sustained play (Self-Determination Theory):

- **Autonomy** — meaningful choices (hazard draft, positive selection, placement). Forced daily requirements kill this. Overlap defers daily reqs.
- **Competence** — visible mastery (lap times, multiplier held, fewer deaths). Playerswho can't *see* their improvement stop feeling it.
- **Relatedness** — not applicable yet (no social layer). Deferred.

**Reward scheduling:**
- **Variable ratio** — coins scale with multiplier; drift rewards are unpredictable. Most engaging.
- **Fixed ratio** — per-lap multiplier increment. Steady.
- **Fixed interval** — round timer. Session pacing.

**Ethical line:** if a player who knew exactly how the system works would still want to play, the system is honest. If no, it's manipulation. Overlap defers meta-progression, daily rewards, and social obligation by design — these are intentional absences.

---

## 4. Flow and Difficulty

Challenge should track skill. Too easy = bored. Too hard = frustrated. Between = flow.

**Overlap's difficulty levers are all player-facing:**
- Track mutation lengthens the course — scales with earnings the player generated
- Hazard draft — player chose which difficulty to accept
- Time Bank purchase — self-regulated difficulty floor
- No adaptive difficulty — player agency sets the curve

**Low floor, high ceiling.** Round 1 should be trivially survivable. Round 10 should be a hostile machine the player built for themselves.

Difficulty through behavior (readable hazards, tighter racing lines), not stat scaling. Principle 2.

---

## 5. Encounter Framing

A lap through the current track IS the encounter. The Encounter Triangle maps:

- **Space** — track geometry + active mutations
- **Adversaries** — placed hazards (Oil Slick, Wall Barrier, Cone Chicane, Slow Zone, Gravel Spill, Crosswind Fan, Shutter Gate)
- **Resources** — placed positives (Boost Pad, Coin Gate, Drift Ribbon, Wash Gate, Time Bank) + remaining timer + current multiplier

**Hazard archetypes (already in `hazard_type.gd`):**
- **Line Tax** — makes the existing racing line expensive (Oil Slick, Slow Zone, Gravel Spill, Crosswind Fan)
- **Hard Reroute** — forces a new line (Wall Barrier, Cone Chicane, Shutter Gate)

**Composition rule:** a lap needs at least one of each archetype to stay interesting. All line-tax = grind. All hard-reroute = maze with no line to optimize. Draft offers already enforce one-of-each.

**Readability is non-negotiable.** If a player dies to a hazard they couldn't identify by silhouette + color + audio at gameplay distance, that's a design failure, not a skill failure.

---

## 6. Player UX

Attention is finite. Working memory holds ~4 chunks. Every HUD element, every visual cue, every tutorial step must earn its place in that budget.

- **Usability failures masquerade as difficulty problems.** If a player can't do what they intend, they blame themselves — the UI is at fault.
- **Recognition > recall.** Show the current multiplier, don't ask the player to remember it.
- **Color + shape + audio** for critical cues, not color alone. Accessibility and robustness overlap.
- **Onboarding scaffolds then removes itself.** Round 1 is the tutorial.
- **Developer blindness** — you've used this HUD 1000 times. A fresh playtester sees it once, in motion, under pressure.

---

## 7. Playtest Discipline

Trust hierarchy when interpreting feedback:

1. **What players did** (behavioral data) — most reliable
2. **What players felt** (experience reports) — reliable for feelings, unreliable for causes
3. **What players say caused the feeling** (causal attribution) — least reliable

**Solo-dev bias:** after 100 laps, your intuition is NOT the first-timer experience. Minimum viable external validation: 3 fresh testers. Small N still beats unbounded solo play.

**Observe > ask.** Hesitation moments, rage-quit points, where the eye lands, body language — these beat post-session surveys every time.

**Self-testing tricks:**
- 2-week break before revisiting a tuning change
- Mute the game (remove audio feedback) and drive — does it still feel OK?
- Squint test (blur vision) — can you still read the track?

---

## Cross-Cutting Anti-Patterns

Collected from design practice, filtered to what applies in prototype phase:

- **Stat-only differentiation.** "+5% speed" is not a car class (principle 3). Classes must change *how* the player plays.
- **Realism creep.** Starting from a real vehicle model and fighting toward arcade feel (principle 7). Build up, don't constrain down.
- **Designing before prototyping.** Long GDDs are procrastination (principle 5). A 2-minute driveable prototype beats a 50-page spec.
- **Silent surfaces.** Handling change without an audio/visual cue (live gap in Overlap). The player must see and hear what just happened to their car.
- **Dominant-strategy drift.** If drift is always better than cornering, drift has eaten the game. Verify via pick rates.
- **Hidden retention.** If a player who saw the drop tables / timers / algorithms would still want to play, the system is honest. If not, it's manipulation.
- **Stat-sponge hazards.** "More HP" is not difficulty in a racing game (no combat anyway). A hazard has to change what the player *does*, not how long something takes.
- **Solving the wrong link.** Tuning `grip` when the complaint is "laggy." Use the feel diagnostic first.

---

## References

These frameworks draw on standard game design literature (Self-Determination Theory, flow theory, operant conditioning, feedback layering, encounter design methodology). Sources are not cited inline — the toolkit is distilled from common industry practice, and every claim should still be tested against real play before being trusted. Principle 5 applies to the toolkit itself.
