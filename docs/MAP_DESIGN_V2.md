# Overlap — The Island v2 (full relayout)

Status: DESIGN, human-approved direction 2026-07-07 ("initial loop
should be like 15 seconds — a 5 second lap doesn't feel race-y").
Supersedes the *geography* of MAP_DESIGN.md; its pillars, zone grammar,
authoring rules, and route-design lessons all carry over. Build order:
design everything here, build the hub first, re-adapt the annex content
in follow-up slices.

## 0. What changes and why

v1 grew petal-by-petal around a rectangular hub authored in slice 1.
Its 6 s heartbeat lap was right for a pure idle clicker but wrong for
the game this is becoming: with rivals on the horizon (docs/IDEAS.md),
a lap must be long enough to *race* — to lose the leader, catch them,
and beat them on a line, not a twitch. v2 designs the whole island as
one composition around a **~15 s GP-style hub circuit**:

- Hub lap target **~15 s** (≈14k px at the calibrated ~900 px/s).
  Fast + flowing: one long start straight, drift-rewarding sweepers,
  ONE heavy braking corner, no hairpins on the hub.
- Whole-track-on-screen readability is retired; **flow readability**
  (see the next corner early, learn the rhythm) replaces it. A
  **minimap/map screen moves up to a required v2 slice**.
- Junction rules from MAP_DESIGN §4 are designed in from day one, not
  grandfathered: ≥1600 px between consecutive *decision* mouths on a
  road (merge-only mouths don't count), crossing lines never on shared
  or crossing asphalt, gates visibly fence visible asphalt.
- Zones keep their v1 identities and showrooms (dunes/grip W, cliffs/
  skill N, harbor/accel E, coast/top-speed S, secret woods NW); their
  geometry re-attaches to the new hub in re-adaptation slices.
- The X crossover survives as THE Overlap moment: the cliffs descent
  crosses the top straight at grade into the chord.

## 1. The island v2 at a glance

World grows to ~12k × 8k px (water margin ~800 px beyond land).

```
   ~~~~~~~~~~~~~~~~~~~~~~~~ open water ~~~~~~~~~~~~~~~~~~~~~~~~
  ~        WOODS (secret)      ⌂ CLIFFS (lighthouse, ladder)     ~
  ~   ╭─────forest arc────╮      ╲ esses → descent               ~
  ~   NW sweep ╔═══ top straight ═╪═══════╗ NE sweeper           ~
  ~  DUNES     ║  (kink)   chord ↓X       ║                      ~
  ~  (bowl) ═══╣           │              ╠═ esses ═ HARBOR      ~
  ~  sweepers  ║ west      │ chord        ║ (containers,         ~
  ~         ═══╣ riser     │              ╠═ carousel  cranes)   ~
  ~            ║ T1 ═══════╪══════════════╝                      ~
  ~            ╚═ START STRAIGHT (4.8k px, the ghost river) ═╝   ~
  ~                └── COAST ROAD (linker, off T1) ──┘           ~
   ~~~~~~~~~~~~~~~~~~~~~~~~~ water ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

## 2. The hub circuit (build slice V2-1)

Travel direction unchanged from v1: cross the start line westbound,
climb the west side, run the top eastbound, descend the east side.
Width 300 (half_width 150), border 26. Segment is ONE closed centerline
(seam mid-straight where curvature is zero; square caps self-seal).

Authored centerline (in-handle, out-handle, position; y-down coords):

| # | pos | in | out | what |
|---|-----|----|-----|------|
| 0 | (1400, 1200) | — | (-800, 0) | seam, mid start straight |
| 1 | (-1500, 1200) | (700, 0) | (-500, 0) | straight west end |
| 2 | (-2450, 1080) | (260, 60) | (-170, -40) | **T1 entry — the braking zone** |
| 3 | (-2620, 700) | (30, 160) | (-30, -160) | T1 apex (tight, ~220 radius) |
| 4 | (-2350, 100) | (-120, 220) | (120, -220) | riser sweeper right |
| 5 | (-2700, -700) | (160, 220) | (-160, -220) | riser sweeper left |
| 6 | (-2350, -1250) | (-220, 120) | (220, -120) | NW turn, opens east |
| 7 | (-1000, -1450) | (-400, 40) | (400, -40) | top straight west |
| 8 | (0, -1380) | (-330, -30) | (330, 30) | top kink (flat-out) |
| 9 | (1000, -1450) | (-330, 30) | (330, -30) | top straight east |
| 10 | (1900, -1250) | (-260, -40) | (260, 40) | NE sweeper entry (fast right) |
| 11 | (2300, -800) | (-60, -240) | (60, 240) | NE exit, heading south |
| 12 | (1950, -250) | (140, -200) | (-140, 200) | ess left |
| 13 | (2350, 300) | (-160, -180) | (160, 180) | ess right |
| 14 | (2650, 750) | (-40, -240) | (40, 240) | carousel entry |
| 15 | (2350, 1150) | (240, -60) | (-240, 60) | carousel exit onto straight |
| 16 | = #0 | (500, 0) | — | close the loop |

Rhythm read: flat-out start straight (~4.8k px — the ghost river and
the future side-by-side racing stage) → hard brake at T1 (the one
overtaking spot; also the future coast-road fork, so the gate is what
you stare at while braking) → drift-rewarding riser sweepers → NW onto
the flat-out top with a kink → fast NE sweeper → east esses (rhythm
section, future harbor mouths) → long carousel that rewards carried
speed onto the straight. Estimated 13.5–14.5k px ≈ 15 s calibrated;
first unupgraded human laps ~17–18 s. **Trim/stretch geometry after
the first calibration run, not before.**

**The chord** (first gate, `island_chord`, keeps v1's $120): straight
north-south at x=500 from the top straight (mouth ~(500, -1400)) to the
start straight (mouth ~(500, 1200)). Cut lap ≈ 10k px ≈ 11 s. Start
line stays at x=0 (car spawns ~(600, 1200) facing west): 350 px from
the chord's bottom-mouth asphalt — at the line-placement minimum, keep
it in mind if the chord moves. The cliffs descent later crosses the top
straight at the chord's top mouth, upgrading it to the at-grade X
crossroads exactly like v1.

Crossing lines (ids unchanged from v1, so RouteDefs keep their shape):
`start` x=0 on the start straight; `west` mid-riser between sweepers
(~y=-300); `east` mid-esses (~y=0-ish, x 1850..2650, forward=south);
`chord_mouth` just south of the top junction; `chord` mid-chord.
Initial routes: **Grand Ring** (west, east) and **Island Cut** (west,
chord_mouth, chord).

## 3. Zone re-adaptation plan (follow-up slices)

Mouths named now so spacing is designed, not discovered:

- **DUNES (west)** — annex west of the riser. Decision mouth off
  sweeper #4 (~(-2350, 400)); merge mouth off sweeper #5
  (~(-2500, -900)); ≥1600 apart along the road. Dune Bend becomes a
  25–30 s route; the Outer Dunes bowl extends to x ≈ -5000.
- **CLIFFS (north/NE)** — same shape as v1, more room: approach forks
  off the NE sweeper (continue straight where the hub bends south),
  ladder + lighthouse climb toward y ≈ -3800, esses west along the
  north shore, descent dives south crossing the top straight at
  (500, -1400) — the X — into the chord. Lighthouse Climb ~35–40 s.
- **WOODS (NW, secret)** — forest arc north of the top straight's west
  half. Golden-gap trigger off the top straight; entrance mouth
  ~x=-1900, merge-only rejoin ~x=-1100 (spacing to chord mouth 1600 ✓
  because rejoins don't count as decisions). Forest Run ~30 s.
- **HARBOR (east)** — container maze east of the esses. Decision mouth
  off ess #12 (~(2050, -350)); merge into the carousel entry
  (~(2600, 600)). Dock straight runs the east shore. 30–40 s routes.
- **COAST (south)** — the linker forks off T1 (continue straight
  instead of braking — the most legible gate placement on the island)
  and runs the south beach to the harbor's south edge. Enables the
  grand tour (~2.5–3 min lap).

Lap ladder v2: hub 15 s → petal routes 25–40 s → two-zone combos
45–70 s → coastal grand tour 150–180 s. Same per-second normalized
economy; long routes pay chunkier, never strictly more.

## 4. Consequences to design around

- **Cold start slows**: first PB (and first auto-ghost) arrives at
  ~17 s instead of ~6 s, first purchase drifts from ~30 s toward
  ~60–90 s. Mitigations if the sim/playtest wants them: raise
  active_lap_multiplier (3 → 4), price ring payout ≈ 25/lap so
  income/s matches v1 (~1.7/s/slot), or cheapen ghost slot 2. Re-run
  the economy sim (docs/DESIGN_NOTES.md) after the hub calibrates.
- **Ghost density thins ~2.8×** per slot (same fleet spread over a
  longer lap) — pillar 2 pressure. The start-straight funnel keeps the
  river image; if it reads sparse, cheapen early slots rather than
  shortening the lap.
- **Minimap becomes required** (slice V2-2): fog-of-war island outline,
  driven asphalt drawn, gate pins. The circuit no longer fits a screen.
- **Recording size** ~5× v1 (still trivial: 30 Hz × 15 s ≈ 450 samples).
- **Full save wipe** (human-approved): bump save version; the loader
  wipes older versions instead of migrating. PBs, routes, medals,
  currency, upgrades all reset — pre-release clean slate.

## 5. Migration & build order

1. **V2-1 The hub** — track02 scene (hub loop + chord + water/zones
   backdrop + dressing), network v2 (5 lines, 2 routes, 1 gate), save
   v4 wipe, probe/calibrator/photo retargeted, pars + payouts from a
   calibration run, economy sim re-check. Main switches to track02;
   track01 and its petal content are deleted the same slice (dead
   scenes rot — the annex designs live in this doc and git history).
2. **V2-2 Minimap** + camera look-ahead polish.
3. **V2-3 Dunes re-adaptation** (first annex proves the mouth plan).
4. **V2-4 Cliffs + Woods re-adaptation** (the X returns; rival-ready).
5. **V2-5 Harbor** (first new-content zone), then coast/Jump Kit/grand
   tour per MAP_DESIGN §8 — unchanged.

Rival onboarding (IDEAS.md) slots in any time after V2-1 — the 15 s
hub is designed for it.
