# Timer, Multiplier & Coins — Design Exploration

Phase 1 items 5 and 6 from the brief. The timer, lap reward, multiplier, HUD, and a first-pass coin collectible are now implemented in the prototype. The notes below still capture useful follow-up questions and expansion directions.

---

## What We're Adding

Three connected systems that turn "drive in circles" into a game loop with pressure and reward:

1. **Round timer** — countdown that ends the round when it hits zero
2. **Lap multiplier** — starts at x1, +1 per completed lap, scales all earnings
3. **Coins** — collectibles on the track that award currency x multiplier

Plus a HUD to show all of it.

---

## Run State

New node: `race/run_state.gd`, added to `main.tscn`.

Owns the round state: timer, multiplier, currency. Not an autoload — it's a scene node like LapTracker. Connects to LapTracker's signals to know when laps complete.

**State:**
- `round_time_remaining: float` — seconds remaining, counts down in `_process`
- `current_multiplier: int` — starts at 1, incremented on `lap_completed`
- `currency: int` — accumulated this round, persists across rounds later
- `base_lap_reward: int` — flat currency per lap (exported, tunable)

**Signals:**
- `round_time_changed(time_remaining: float)` — every frame, drives HUD
- `lap_time_changed(current_lap_time: float)` — every frame, drives HUD
- `last_lap_time_changed(last_lap_time: float)` — on lap completion
- `multiplier_changed(new_multiplier: int)` — on lap completion
- `currency_changed(new_total: int)` — on any earning event
- `round_finished()` — timer hit zero

**Flow:**
1. Round starts. Timer counts down. Multiplier is x1.
2. Player completes a lap -> earns `base_lap_reward * current_multiplier`, multiplier increments.
3. Player hits a coin -> earns `coin_value * current_multiplier`.
4. Timer hits zero -> `round_finished` fires. For now, just freezes state. Pit stop comes later.

**Open question — timer duration:**
Round 1 should be generous. 60 seconds? 90? This is a feel question we'll need to playtest. Make it an `@export` and try values. The track perimeter is ~353 units and max speed is 25 units/s, so a full lap takes roughly 14 seconds at top speed, probably 18-22 in practice. So 60 seconds gives ~3 laps, 90 gives ~4-5. Lean toward 90 for round 1 so the player gets to feel the multiplier ramp.

**Open question — multiplier reset:**
Per the brief, multiplier resets each round. But we only have one round right now. Build it to reset, add a `start_round()` method, but don't worry about multi-round flow yet.

---

## Coins

New scene: `race/coin.tscn` with script `race/coin.gd`.

**Node structure:**
```
Coin (Area3D)
  CollisionShape3D (cylinder or sphere)
  MeshInstance3D (visual — simple cylinder or torus, gold-colored)
```

**Behavior:**
- Area3D detects car overlap via `body_entered` signal
- On collection: emits `collected(value: int)`, then hides and disables collision
- In the current prototype, respawns on each completed lap so they reward consistent racing lines instead of one-time pickups
- Coin value is exported on the coin itself (default: 1 or maybe 10)

**Placement:**
For now, manually place 4-6 coins around the oval. Put them on the racing line — the player should collect them naturally when driving well, not by swerving dangerously. The "hard" coins that require risky lines come later when we have more track variety.

Later, coins will be placed by the player during the pit stop phase. For now they're just static scene children.

**Collision layer:**
Coins need a new collision layer. Per AGENTS.md, claim the next free one:

| Layer | Name | Used by |
|-------|------|---------|
| 1 | car | Car RigidBody3D |
| 2 | track_wall | Track wall StaticBody3Ds |
| 3 | track_surface | Reserved |
| 4 | collectible | Coins, pickups |

Coins set `collision_layer = 4`, `collision_mask = 1` (detect car only). Car already has `collision_layer = 1`.
Actually — since coins are Area3D, not physics bodies, they use `monitoring` and connect to `body_entered`. The car's RigidBody3D will trigger Area3D overlap as long as the Area3D's collision mask includes the car's layer. So: coin `collision_layer = 4`, coin `collision_mask = 1`.

---

## HUD

Replace the old `LapCounterHUD` with a more complete `RunHUD`.

**Approach — expand vs replace:**
The current implementation uses `ui/run_hud.gd` to display lap, lap time, last lap, round timer, multiplier, and currency. It connects to both LapTracker and RunState.

**Layout (rough):**

```
+----------------------------------+
| Lap 3          x3       $1,240   |
|                                  |
|                                  |
|                                  |
|                                  |
|              0:47                |
+----------------------------------+
```

- **Top-left:** Lap counter (as now)
- **Top-center:** Multiplier with a punch animation on increment
- **Top-right:** Currency earned this round
- **Bottom-center:** Timer, large, gets red/shaky below 10 seconds

For now, all Labels in a CanvasLayer. No fancy animation yet — just the information displayed. Juice comes after the loop feels right.

**Multiplier display:**
Show "x3" not "3x". When it increments, a simple scale tween (1.0 -> 1.3 -> 1.0 over 0.3s) gives satisfying feedback without complex animation code. Godot's built-in Tween is enough.

**Timer urgency:**
When timer drops below 10 seconds, change the label color to red. That's the only urgency cue needed for prototype. Screen shake and sound come later.

---

## Wiring

**Signal flow:**
```
LapTracker.lap_completed --> RunState._on_lap_completed()
                             (increment multiplier, award lap currency)

Coin.collected           --> RunState.add_pickup_currency(value)
                             (award value * multiplier)

RunState.round_time_changed --> RunHUD (update timer display)
RunState.multiplier_changed --> RunHUD (update multiplier display)
RunState.currency_changed   --> RunHUD (update currency display)
LapTracker.lap_changed      --> RunHUD (update lap display)
```

RunState connects to LapTracker and coins via NodePaths or scene-tree lookups. RunHUD connects to RunState and LapTracker. No autoloads, no global state.

---

## File Plan

| File | Type | Purpose |
|------|------|---------|
| `race/run_state.gd` | New script | Timer, multiplier, currency state |
| `race/coin.gd` | New script | Collectible behavior |
| `race/coin.tscn` | New scene | Coin prefab (Area3D + mesh + collision) |
| `ui/run_hud.gd` | New script | Full race-state display |
| `ui/lap_counter.gd` | Delete | Replaced by run_hud.gd |
| `main.tscn` | Modified | Add RunState, RunHUD, place coins, remove LapCounter |
| `AGENTS.md` | Modified | Add collectible collision layer, run_state to key files |

---

## Implementation Order

1. **RunState** — implemented. Timer countdown + multiplier increment on lap.
2. **RunHUD** — implemented. Displays timer, multiplier, currency, lap, and lap times.
3. **Coins** — implemented. Coin scene, oval placement, and multiplier-scaled rewards are wired in.
4. **Round end** — partially implemented. `round_finished` fires when timer hits zero; explicit round-over presentation and pit stop flow are still separate tasks.

Each step is one scoped commit that can be tested independently.

---

## What This Doesn't Cover (Yet)

- Pit stop phase (buy/place items between rounds)
- Multi-round flow (restart timer, carry currency)
- Coin placement by the player
- Timer extensions as purchasable items
- Sound / broader juice pass beyond the current drift smoke feedback

Those build on top of this foundation but are separate tasks.
