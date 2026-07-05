# Overlap — Roadmap

Vertical slices, in order. Each slice ends with the game playable and its
acceptance line verified by running it (godot-mcp run + screenshot/output).
Tick when done. Notes about deviations go under the slice, not in new files.

## Slice 1 — A car that feels great on one track
- [x] Input map (WASD + arrows + Space drift), Car scene with
      forward/lateral-split controller, drift factor
- [x] One hand-built track scene (simple closed circuit, walls)
- [x] Follow camera
- [ ] **Accept:** drive 3 clean laps; steering and drift feel good at speed.
      Feel sign-off is the gate — iterate here before moving on.
- Notes: auto-verified 2026-07-05 via DevProbe (scenes/dev/dev_probe.gd —
  scripted drive, telemetry, screenshots to user://dev/; activate by
  creating user://autopilot.flag). Accel 0→920 px/s, cornering, drift and
  wall collisions all behave. Feel tuning: data/cars/starter_car.tres.
  Follow-up playtest chose the drift-heavy candidate over kart/GT; main now
  biases slightly more drifty and adds tire trails while drifting. Rejected
  driving-style branches/worktrees were removed after folding the chosen feel
  into main. Human playtest 2026-07-05: feel signed off as-is. Trails now
  spawn a fresh Line2D pair per drift stint (old ones fade after 4 s — fixes
  stints connecting across the map) and also draw from keyless sideways
  scrub. Road-edge walls and island collision replaced by slowing grass
  (grass_speed_multiplier/grass_deceleration in starter_car.tres); walls
  remain only at the world edge.

## Slice 2 — Laps exist
- [x] Start line + 3 checkpoints on Track; ordered lap validation
- [x] RaceState: lap timer, best lap, HUD showing current/best/last
- [x] **Accept:** crossing the line after all checkpoints logs a lap time;
      cutting the track does not.
- Notes: verified 2026-07-05 — DevProbe waypoint autopilot completed two
  clean laps (7.10s, 7.04s); checkpoints fired in order; first start-line
  crossing started the clock without logging a lap; HUD confirmed via
  screenshot. Track owns validity, RaceState owns time, HUD reads only.

## Slice 3 — Your ghost drives
- [x] LapRecording resource; RaceState records during each lap (30 Hz)
- [x] Ghost scene replaying the best lap on loop, translucent; GhostFleet
      re-arms every ghost on a new PB
- [x] **Accept:** set a lap, ghost appears and retraces it accurately while
      you keep driving.
- Notes: verified 2026-07-05 — 214 samples @ 33.3 ms for a 7.10 s lap;
  ghost traced the recorded line within interpolation error while the car
  drove a different line; three consecutive PBs re-armed the fleet each
  time. Ghost has no physics and no collision (hard rule 5 holds).

## Slice 4 — Ghosts pay
- [x] Bank autoload (currency; each ghost lap pays TrackDef.base_payout,
      so income/s = payout / lap_time)
- [x] HUD money counter + income rate, ticking per ghost lap
- [x] Save/load (currency + best LapRecording via store_var; 5 s autosave
      and save-on-PB and on close)
- [x] **Accept:** ghost earns → money rises each ghost lap → quit and
      relaunch → state intact.
- Notes: verified 2026-07-05 — parked car, ghost paid $10 exactly every
  7.03 s (income 1.42/s = 10/7.03); relaunch restored money + PB, spawned
  the ghost at t=0, and correctly flagged 7.10 as not-a-best against the
  persisted 7.03. Ghost auto-hires on first PB; purchasable slots are
  slice 5.

## Slice 5 — Spend it
- [x] UpgradeDef + UpgradeCatalog resources (top speed / accel / grip,
      data-authored cost growth, multiplicative effects) + Tab-toggled GARAGE shop
- [x] Car computes effective stats (base resource × upgrade multipliers,
      base .tres never mutated); refreshes on purchase and from save
- [x] Ghost slots from data/economy.tres; fleet grows and staggers clones
      evenly around the lap
- [x] **Accept:** full loop closes — earn, buy speed, set faster lap,
      fleet re-arms, income visibly increases.
- Notes: verified 2026-07-05 across two runs — income 1.42/s → 4.61/s
  (3 ghosts × $10 / 6.51 s PB); saved upgrade levels applied to physics on
  relaunch (974 px/s straight from load). Re-verified 2026-07-05 after
  steering-floor, drift tuning, trails, and DevProbe hardening: upgraded
  clean lap improved 6.90 s PB → 6.61 s, fleet income rose to 3.02/s with
  2 ghosts.

## Slice 6 — Idle game shape
- [x] Offline earnings on launch ("While you were away…")
- [x] More ghost slots, cost curves from data/ (already live since slice 5:
      unlimited slots, cost = ghost_base_cost × growth^n from economy.tres;
      slots apply per route fleet since slice 7)
- [x] ~~Second track (TrackDef unlock)~~ SUBSUMED by the gate network
      (slice 7): new asphalt arrives as gated routes on one growing
      network, not separate track scenes.
- **Accept:** relaunching after time away grants income; buying track 2 and
      racing it with its own ghosts works.
- Notes: verified 2026-07-05 via temporary save/load run — 2 ghosts, $10
  payout, 10.0 s PB, and ~1 h elapsed launched from $100 to ~$7300 and
  rewrote the save timestamp. Offline cap lives in data/economy.tres.

## Slice 7 — The gate network (design: docs/GATE_NETWORK.md on design branch)
- [x] Pretzel-lite prototype: island gate ($120 in GARAGE) opens a chord →
      2 authored routes (Grand Ring / Island Cut), analytic line-crossing
      route detection (RouteTracker, no Area2D checkpoints), per-route
      PB/recording/ghost fleet in Bank (save v3 + v2 migration),
      route-discovery toast, par-normalized payouts.
- [x] Route log UI (R key): full cards (name/PB/income) for discovered,
      ??? + authored clue for hinted (gates owned, undriven), X/N counter.
      Gate hardened: 700 px bar + chord_mouth line required in the cut's
      edge sequence, so flanking the gate over grass validates nothing.
- [x] Path2D road pipeline: RoadSegment (@tool) bakes surface + grass
      hitbox from a Curve2D centerline (tessellate + offset_polyline,
      square caps seal junctions). track01 rebuilt from 5 centerlines,
      byte-for-byte drivable-area equivalent — probe lap times identical.
- [x] Clover petal 1: sand-themed curved petal (Dune Gate $250) west of
      the ring; routes Dune Bend + Twin Cut (two-gate combo, hinted until
      driven); mastery medals from PB vs par (data/economy.tres knobs)
      multiply that route's fleet income. Probe-verified; pars set so
      autopilot-clean laps land silver. Human feel pass on the curve +
      Twin Cut par (never driven) still pending.
- [ ] Petals 2-3, Jump Kit gateway upgrade, knowledge route,
      gate-exhausted badges (see design §2 rules 7-10)
- **Accept (prototype):** buy gate → drive chord → NEW ROUTE toast, own
      PB and fleet, income adds up across routes.
- Notes: prototype verified headless 2026-07-05 — gate bought, Island Cut
  discovered on first lap through it, cut PB 5.12 s, income 3.01 → 5.55/s
  (exactly Σ slots × payout / pb), 4 ghosts in 2 fleets, v2 save migrated
  with offline earnings intact. Human feel pass on the cut still pending.

## In review (branches, 2026-07-05 autonomous session)
- `design/gate-network` — full gate/route-discovery design + topology
  diagrams + research (docs/GATE_NETWORK.md there). Recommendation:
  Clover topology, Pretzel-lite prototype first. KEEP — later slices
  still reference it.
- `proto/gate-network` — FOLDED into main 2026-07-05 (Pretzel-lite
  prototype, see slice 7). Branch and worktree deleted.
- `polish/quality-pass` — FOLDED into main 2026-07-05 (ghost tint variety,
  garage milestone label, HUD next-purchase hint cherry-picked; superseded
  steering-floor commit dropped). Branch and worktree deleted.

## Later (unordered)
- Prestige/reset layer; more cars (CarStats variants); track hazards that
  make YOUR lap risky but ghosts immune (risk = better recorded lines);
  audio + drift trails + screenshake juice pass; web export.
- Engine bump to Godot 4.7.x once 4.7.1 lands (brew has 4.7.0 now; shared
  binary also serves fieldbound/overlap — coordinate before upgrading).
- GdUnit4 tests for Bank math once the economy stabilizes (slice 6+), not
  before.
