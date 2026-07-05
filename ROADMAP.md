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
- [ ] LapRecording resource; RaceState records during each lap
- [ ] Ghost scene replaying the best lap on loop, translucent
- **Accept:** set a lap, ghost appears and retraces it accurately while you
      keep driving.

## Slice 4 — Ghosts pay
- [ ] Bank autoload (currency, income = track_value / lap_time per ghost)
- [ ] Events bus; HUD money counter ticking up per ghost lap
- [ ] Save/load (Bank state + best LapRecordings)
- **Accept:** hire ghost → money rises each ghost lap → quit and relaunch →
      state intact.

## Slice 5 — Spend it
- [ ] UpgradeDef resources + shop UI (3 upgrades: top speed, grip, accel)
- [ ] Upgrades change CarStats → faster laps possible → re-record ghost
- [ ] Second ghost slot purchasable
- **Accept:** full loop closes — earn, buy speed, set faster lap, replace
      ghost, income visibly increases.

## Slice 6 — Idle game shape
- [ ] Offline earnings on launch ("While you were away…")
- [ ] More ghost slots, cost curves from data/
- [ ] Second track (TrackDef unlock)
- **Accept:** relaunching after time away grants income; buying track 2 and
      racing it with its own ghosts works.

## Later (unordered)
- Prestige/reset layer; more cars (CarStats variants); track hazards that
  make YOUR lap risky but ghosts immune (risk = better recorded lines);
  audio + drift trails + screenshake juice pass; web export.
- Engine bump to Godot 4.7.x once 4.7.1 lands (brew has 4.7.0 now; shared
  binary also serves fieldbound/overlap — coordinate before upgrading).
- GdUnit4 tests for Bank math once the economy stabilizes (slice 6+), not
  before.
