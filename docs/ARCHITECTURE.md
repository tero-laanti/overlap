# Overlap — Architecture

Current as of the slice-7 gate network + visual identity pass (2026-07-07).

## Ownership map

Every piece of state has exactly one owner. If you're unsure where something
goes, this table decides.

| Owner | Owns | Never owns |
|---|---|---|
| `Bank` (autoload) | currency, per-route PB recordings, discovered routes, purchased gates, medal unlocks, unlocked secrets, upgrade levels, ghost slots, save/load, offline earnings | scene nodes, per-frame gameplay (its only `_process` is the autosave timer) |
| `Events` (autoload) | cross-scene signals only (see autoload/events.gd for the full list) | state of any kind |
| `Main` scene | instantiating track/car/UI, wiring signals | gameplay rules, flow state |
| `Car` scene | input, movement, drift physics, surface queries (road/water/rubble), drift trails, splash reset | economy, lap validity |
| `Track` scene | baked road geometry, gates, secret roads, lap validity via its RouteTracker child (including the owned-gates certification check) | car behavior, money |
| `RouteTracker` (in Track) | analytic crossing-line detection, the lap edge accumulator | timing, scene geometry (consumes only TrackNetworkDef) |
| `RaceState` node (in Main) | current lap timing, per-route bests, recording lifecycle | currency (reports via Events) |
| `Ghost` / `GhostFleet` | replaying LapRecordings; one fleet per route with a PB, clones staggered around the lap | physics, decisions, collision |
| UI scenes (hud, shop, route_log) | presentation + purchase intents; ShopPacing (static) decides what the GARAGE offers | any math; they read Bank, never write it except via `Bank.try_buy_*` |

Bank stays under the line ceiling by delegating to static helpers that
operate on it: `BankSave` (save IO), `BankMedals` (mastery medals).

## Key data types (Resources)

- **LapRecording** — fixed-rate transform samples (`sample_dt`, `positions`,
  `rotations`) plus `lap_time`. Recorded at 30 Hz (every 2nd physics tick).
  Produced by RaceState, replayed by Ghost, persisted per route by Bank.
  This is the central artifact of the whole game.
- **TrackNetworkDef** — one track's gate network: crossing lines, authored
  routes, purchasable gates. RouteTracker consumes only this, so route
  detection is headless-testable and independent of scene geometry.
- **RouteDef** — ordered edge-id sequence, par time, payout per lap, medal
  unlock cost, `secret` flag, clue, required gates.
- **GateDef / CrossingLineDef** — id + price / id + segment endpoints.
- **CarStats** — movement, grass/rubble, and drift-trail tuning. The base
  resource is never mutated; Car duplicates it and applies upgrades.
- **UpgradeDef / UpgradeCatalog** — stat name, cost curve, multiplier, max
  level, shop reveal threshold.
- **EconomyDef** (data/economy.tres) — ghost slot costs, active-lap and
  milestone multipliers, offline cap, medal factors/multipliers.
- **TrackDef** — legacy (scene path/base payout); currently unread. Route
  payouts live on RouteDef.

## Route detection (how a lap certifies)

- The car's per-physics-tick movement segment is tested against every
  crossing line — analytic, tunnel-proof at any speed, no Area2D.
- Forward crossings append edge ids; backing over the last edge pops it;
  any other backward crossing dirties the lap. Crossed lines disarm until
  the car is 48 px away, so skimming can't double-fire.
- Crossing the start line closes the accumulated edges: a clean sequence
  that exactly matches an authored RouteDef completes that route — but only
  if every `required_gates` entry is owned (gates are physical bars too;
  the ownership check makes flanking one over grass worthless).
- Authoring rule: line spans must overhang the drivable ribbon (surface +
  border curb) on both sides, except where a colinear neighbour line or an
  adjacent cliff rung's rubble apron constrains them.

## The ghost system (get this right first)

- Recording: RaceState samples the car at 30 Hz into a LapRecording; a new
  route best is published on the Events bus and persisted by Bank.
- Replay: Ghost is a plain Node2D. Each frame it interpolates between
  samples by elapsed time (loops forever); `playback_offset` staggers a
  fleet's clones evenly around the lap. No physics body, no collision.
- Fleets: GhostFleet keeps one child fleet per route with a recording;
  `Bank.ghost_slots` applies to every route's fleet. A new PB re-arms the
  whole fleet at once.
- Cost: dozens of ghosts = dozens of interpolations. Trivial. Never let
  this become physics.

## Economy

- Per ghost lap: `payout_per_lap × milestone_multiplier × medal_multiplier`.
- Per player lap: `payout_per_lap × active_lap_multiplier ×
  milestone_multiplier` — active play always out-earns watching.
- `income_per_second = Σ over routes with a PB: ghost_slots × payout ×
  milestone × medal / pb`.
- Offline: `earned = income_per_second × min(elapsed, offline_cap)`.
- Medals are derived from PB vs authored par, never stored, and only count
  once that route's mastery is bought.
- All curves/multipliers live in data/ resources; Bank only evaluates them.
- Saves: v3 dictionary via `store_var` (plain data, no serialized objects),
  written atomically (temp file + rename); v2 saves migrate on load.

## Directory layout

```
scenes/
  main/     main.tscn, main.gd, race_state.gd
  car/      car.tscn, car.gd, car_stats.gd, follow_camera.gd, upgrade_*.gd
  ghost/    ghost.tscn, ghost.gd, ghost_fleet.gd, lap_recording.gd
  track/    track.gd base + RouteTracker, RoadSegment/WallSegment bakers,
            gate/secret_road/defs; track01/ scene
  ui/       hud, shop (+shop_pacing), route_log
  dev/      dev_probe (integration autopilot), dev_calibrate, dev_driver,
            dev_photo — flag-file activated, see HANDOFF.md
autoload/   bank.gd (+bank_save.gd, bank_medals.gd, economy_def.gd), events.gd
data/       cars/, tracks/, upgrades/, economy.tres (.tres files)
assets/     shaders/ (water, mottle, checker)
docs/       this file, VISION.md, HANDOFF.md, MAP_DESIGN.md, DESIGN_NOTES.md,
            IDEAS.md, econ_sim.py
```

## Physics & rendering conventions

- 2D CharacterBody2D with direct velocity control — not RigidBody2D; arcade
  feel needs it. Movement in `_physics_process` only, 60 Hz tick,
  project-wide physics interpolation on.
- Car feel technique: split velocity into forward and lateral components
  each tick; lateral bleeds off by `exp(-grip × delta)` — drifting = lower
  grip. Off-road caps forward speed (grass) or near-stops it (rubble);
  water teleports back to the last asphalt and voids the lap.
- Physics layers: 1 world, 2 road_surface, 3 water, 4 rubble. The car
  point-queries Area2Ds on 2/3/4 every tick.
- THE Z CONTRACT: water -4, grass -3, zone underlays/island -2, road
  borders -1, surfaces/props/trails/cars 0 (tree order), gantry beam and
  lighthouse fan +1. Drift trails are Main-level z0 siblings — raising any
  surface above z0 hides them.
