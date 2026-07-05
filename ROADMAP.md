# Overlap2 — Roadmap

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
      1.15 cost growth, multiplicative effects) + Tab-toggled GARAGE shop
- [x] Car computes effective stats (base resource × upgrade multipliers,
      base .tres never mutated); refreshes on purchase and from save
- [x] Ghost slots at 10 × 1.08^owned; fleet grows and staggers clones
      evenly around the lap
- [x] **Accept:** full loop closes — earn, buy speed, set faster lap,
      fleet re-arms, income visibly increases.
- Notes: verified 2026-07-05 across two runs — income 1.42/s → 4.61/s
  (3 ghosts × $10 / 6.51 s PB); saved upgrade levels applied to physics on
  relaunch (974 px/s straight from load); GARAGE prices confirmed on
  screen ($66 = 50×1.15², $11 = 10×1.08²). Known quirk: car parked
  nose-to-wall takes long to escape (steering authority scales with
  speed, autopilot never reverses) — car-feel item for later.

## Slice 6 — Idle game shape
- [ ] Offline earnings on launch ("While you were away…")
- [ ] More ghost slots, cost curves from data/
- [ ] Second track (TrackDef unlock)
- **Accept:** relaunching after time away grants income; buying track 2 and
      racing it with its own ghosts works.

## In review (branches, 2026-07-05 autonomous session)
- `design/gate-network` — full gate/route-discovery design + topology
  diagrams + research (docs/GATE_NETWORK.md there). Recommendation:
  Clover topology, Pretzel-lite prototype first.
- `proto/gate-network` — Pretzel-lite prototype (1 gate, 2 routes,
  per-route PBs and fleets, analytic route detection). In progress.
- `feel/drift-heavy`, `feel/grippy-kart`, `feel/heavy-momentum` — three
  car-feel candidates to test-drive; pick one or mix values.
- `polish/quality-pass` — low-speed steering floor, ghost crowd variety,
  milestone + next-purchase UI hints.

## Later (unordered)
- Prestige/reset layer; more cars (CarStats variants); track hazards that
  make YOUR lap risky but ghosts immune (risk = better recorded lines);
  audio + drift trails + screenshake juice pass; web export.
- Engine bump to Godot 4.7.x once 4.7.1 lands (brew has 4.7.0 now; shared
  binary also serves fieldbound/overlap — coordinate before upgrading).
- GdUnit4 tests for Bank math once the economy stabilizes (slice 6+), not
  before.
