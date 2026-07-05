# Design notes from research (2026-07-05)

Distilled, actionable decisions from genre research. Full sources at the
bottom. These are defaults — change them from playtesting, not from vibes.

## Ghosts (slice 3)

- **Transform sampling, never input replay.** Godot physics is not
  deterministic; input-replay ghosts desync (even Mario Kart Wii's do).
  Transform ghosts can't be knocked off course — exactly what an income
  source needs. This confirms CLAUDE.md hard rule 5.
- Record at **30 Hz** (every 2nd physics tick): position + rotation into
  packed arrays. A 30 s lap ≈ 11 KB. Storage is a non-issue.
- **Replay by time, not index**: `idx = floor(elapsed / dt)`, lerp position
  and `lerp_angle` rotation with the fraction. Loop forever.
- Ghosts are plain Node2D + sprite, **no collision at all** (they must
  never trigger checkpoints or block the player).
- **All ghosts on a track replay the single best lap.** Beating your PB
  instantly upgrades the whole fleet — this is IGTAP's core trick and the
  main reason re-driving stays fun.
- Stagger each clone's playback offset so they spread around the track
  instead of stacking into one sprite.

## Economy (slices 4–6)

### Tuned economy v1 (simulated 2026-07-05 — supersedes the raw research
### defaults below; sim: scratchpad econ_sim.py, config "FINAL")

Simulated 60-min sessions with a skill-improving greedy player exposed the
raw research numbers as ~10× too generous here (lap times are seconds, not
minutes — a ghost repaid itself in 1–2 laps and the sim made 240 purchases
in an hour, maxing everything). Tuned so a ghost repays in ~6–8 laps and
purchases stay decisions:

- **Ghost slots: base 25, growth 1.30** (first extra ghost ≈ 30 s of play).
- **Upgrades: growth 1.5, max level 8** — top speed base 75, accel/grip 50.
  Chunky treats between ghost buys, exhausted ~25–30 min in.
- **Milestones ×2 at 10 / 25 / 50 ghosts** (EconomyDef).
- **Active lap bonus ×3**: your own laps pay 3× a ghost lap. Fixes the
  cold start (income from lap 1) and keeps driving strictly better than
  watching.
- Simulated shape: first buy ~20–40 s (human), all four purchase types
  within the first 2 min, income ×29 by 30 min, hard slowdown 25–35 min —
  that wall is where track 2 (10–20×) must land, and later prestige.
- All knobs live in data/economy.tres + data/upgrades/*.tres.

### Original research defaults (kept for reference)

- Cost curves: `cost = base × growth^owned`.
  - Ghost slots: base 10, growth 1.08 (spammy, satisfying).
  - Car upgrades / track unlocks: growth 1.15 (chunky, strategic).
- **Milestones**: ×2 track income at 10 / 25 / 50 ghosts on a track.
- **Multiplicative bonuses only.** Additive bonuses killed Idle Racing GO's
  progression (its league bonus was additive and therefore pointless).
- Each new track ≈ **10–20× income** of the previous one.
- Offline earnings: `rate × min(elapsed, 8 h)` — computed on login, never
  simulated.
- Prestige (later): `p = √(lifetime_earnings / K)`, tune K so the first
  prestige lands at ~45–60 min with roughly +100% gain. Reset should feel
  worth it at +50–200% prestige currency.
- UI psychology: always show the next affordable thing approaching.

## Keeping driving alive (the hybrid's failure mode)

The genre dies when idle income makes active play pointless. Guards:

1. Your best lap multiplies **all** ghosts → driving well is a permanent
   fleet-wide multiplier, not a one-off reward.
2. Car upgrades both unlock new tracks and make old tracks re-drivable
   faster (IGTAP's movement abilities) — the content-reuse engine.
3. **Drafting bonus**: while you actively drive a track, that track earns
   ×2–3. Playing is always strictly better, never required.
4. Aim ~60% of progress from idle, ~40% from active play.

## Lap system hardening (apply when relevant)

- Ordered index gating (done, slice 2) already kills reverse-crossing and
  re-entry exploits.
- If a respawn feature is added: teleporting can fire `body_entered` on
  overlap — disable the car's area monitoring for one physics frame after
  a teleport, and respawn at the last validated checkpoint without
  resetting checkpoint progress.
- Checkpoint lines should span the full road width, slightly into walls.

## Sources

- Kongregate "Math of Idle Games" I & III (gamedeveloper.com); Pecorella,
  "Quest for Progress" (GDC); Idle Racing GO balance postmortem threads.
- IGTAP (Steam) + jank.cool review — clone/income loop analysis.
- Trackmania TMX replay investigation; Mario Kart Wii RKG ghost format
  (input replay + desync history).
- "Build a 2D Top Down Racer with Godot 4.5+" parts 6 & 12 (lap validation
  and timing); electronstudio Godot racing tutorial.
