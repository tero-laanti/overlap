# Overlap — Architecture

## Ownership map

Every piece of state has exactly one owner. If you're unsure where something
goes, this table decides.

| Owner | Owns | Never owns |
|---|---|---|
| `Bank` (autoload) | currency, income rate, purchased upgrades, ghost roster (as data), save/load, offline earnings | scene nodes, anything per-frame |
| `Events` (autoload) | cross-scene signals only (`lap_completed`, `ghost_hired`, `currency_changed`) | state of any kind |
| `Main` scene | instantiating track/car/UI, wiring signals | gameplay rules, flow state |
| `Car` scene | input, movement, drift physics, its own recording tap | economy, lap validity |
| `Track` scene | tilemap/geometry, checkpoints, start line, lap validation, track params resource | car behavior, money |
| `Ghost` scene | interpolating one LapRecording | physics, decisions |
| `RaceState` node (in Main) | current lap timing, best lap, recording lifecycle | currency (reports to Bank via Events) |
| UI scenes | presentation + user intent signals | any math; they read Bank, never write it except via purchase intents |

## Key data types (Resources)

- **LapRecording** — array of timestamped samples (position, rotation), lap
  time, car id, track id. Produced by RaceState, consumed by Ghost and Bank.
  This is the central artifact of the whole game.
- **CarStats** — max speed, accel, steering rate, drift factor, price.
- **TrackDef** — scene path, base payout value, unlock price.
- **UpgradeDef** — id, cost curve, effect kind + magnitude.

## The ghost system (get this right first)

- Recording: RaceState samples the car at a fixed rate (~20 Hz) into a
  LapRecording. Only laps that pass checkpoint validation are keepable.
- Replay: Ghost is a plain Node2D with a sprite. Each frame it interpolates
  position/rotation between samples, looping. No physics body. Modulated
  translucent so the player car reads clearly on top.
- Cost: dozens of ghosts = dozens of interpolations. Trivial. Never let this
  become physics.

## Economy

- `income_per_second = Σ over hired ghosts (track_value / lap_time)`
- Offline: `earned = income_per_second × min(elapsed, offline_cap)`
- All curves/multipliers live in data/ resources; Bank only evaluates them.

## Directory layout

```
scenes/
  main/     main.tscn, main.gd, race_state.gd
  car/      car.tscn + car.gd (one controller; variants via CarStats)
  ghost/    ghost.tscn + ghost.gd
  track/    one folder per track; track.gd base
  ui/       hud, shop, ghost roster
autoload/   bank.gd, events.gd
data/       cars/, tracks/, upgrades/ (.tres files)
docs/       this file, VISION.md
```

## Physics conventions

- 2D CharacterBody2D (or Node2D + manual integration) — not RigidBody2D;
  arcade feel needs direct velocity control.
- Movement in `_physics_process` only. Default 60 Hz tick.
- Car feel technique (from ../topdown): split velocity into forward and
  lateral components each tick; multiply lateral by a drift factor (<1) to
  bleed sideways speed. Drift = temporarily raising that factor.
