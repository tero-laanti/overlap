# The Gate Network — Overlap2's expansion system

Design for the "buy gates, discover routes" endgame. Synthesizes the
2026-07-05 research passes (combinatorial discovery precedents + Godot
branching-track tech). Status: DESIGN — no code yet. Diagrams in
docs/diagrams/.

## 1. Concept

The track is not a list of maps — it is **one growing road network**.
Purchases open **gates** (barriers on branch mouths). A **route** is any
gated-open circuit from the start line back to itself. Each *authored*
route is its own "map": its own PB, its own recording, its own ghost
fleet, all running simultaneously on shared asphalt. You are never shown
the full network: you discover routes by driving them, and the collection
log ("14/23 routes") is the long-term chase.

Why this fits Overlap2:
- The name becomes literal — fleets from different routes overlap on
  shared segments; busy asphalt is the visible progress bar.
- Transform-replay ghosts make coexisting fleets free (no physics, no
  collision, any density).
- The IGTAP fleet-upgrade rule extends naturally: each route keeps its
  own best lap, so every route is a fresh skill investment that pays
  forever.

## 2. Non-negotiable design rules (from research, adopted)

1. **Author the dependency graph before any road geometry** (Boss Keys
   method): gates = locks, money & car upgrades = keys, routes = rewards.
   If the graph is secretly a straight line, fix it on paper.
2. **Routes are authored, not enumerated.** The network's theoretical
   circuit count will exceed the map list; only authored combinations are
   collection entries. Near-duplicate circuits are *shortcut variants* of
   an authored route (affect PB, not identity). This kills the
   2^branches oatmeal problem.
3. **The OutRun rule:** every branch must change at least two of
   {visual theme, hazard/surface profile, payout character}. If it
   can't, it isn't a branch — merge it.
4. **Legible risk grammar:** one branch direction (screen-right at the
   junction) is consistently the riskier, richer choice.
5. **Gates visible, contents invisible.** Barriers are diegetic and
   visible from the road; driven-past gates get map pins. What lies
   beyond is only mapped by driving it.
6. **Purchase gates are hard; upgrade gates are soft.** A ramp branch is
   *barely* clearable pre-upgrade by a skilled driver (lap-time cost),
   trivial after. Sequence-breaking is a feature.
7. **One gateway upgrade mid-game** (Jump Kit) retroactively activates
   branches in 3+ places at once — the "map explodes" moment.
8. **1–2 knowledge routes:** free, unadvertised, discovered by realizing
   a combination exists (metroidbrainia moment).
9. **Discovery = completing a lap** through a novel combination.
   Fanfare + card flip. Never a menu action.
10. **Collection log grammar:** discovered = full card (name, PB, fleet
    income); hinted = silhouette + one-line clue; unknown = counter only.
    Ship the "X/N" counter from day one. Add the **gate-exhausted badge**
    (every route through this gate found) — cheapest high-value feature.
11. **Concertina pacing:** alternate one-obvious-purchase stretches with
    2–3-options stretches.

## 3. Network sizing

Target: **5 purchasable gates + 4–5 binary decision points →
12–16 authored routes** (theoretical space ~24–32; excess demoted to
shortcut variants). Discovery difficulty mix: ~70% found by normal play
after buying gates, ~25% needing deliberate experimentation, ~5%
(1–2 routes) devious/knowledge-gated.

## 4. Topology candidates (diagrams in docs/diagrams/)

### A. Pretzel Ring — `topology_a_pretzel.svg`
Current ring + two gated chords across the island + one gated outer bulge.
- Decision points: 3 · Gates: 3 · Authored routes: 8
- Pros: direct evolution of track01 (ships fastest); chords create
  figure-8 crossovers — ghost rivers cross visibly at the middle.
- Cons: smallest ceiling; chords must differ hard (surface vs jump) to
  pass the OutRun rule.

### B. Clover — `topology_b_clover.svg`
Compact hub ring; three gated petals graft onto it, each sharing one hub
segment; one late gate links two petals directly (bypassing the hub).
- Decision points: 4 · Gates: 4 (+1 linker) · Authored routes: 12–14
- Pros: purest "loop annexation" fantasy — the map visibly *grows*
  outward; each petal is a theme (sand / night / cliff); the petal-linker
  gate is a natural knowledge route.
- Cons: hub segment gets visually crowded (that's also the point).

### C. Interchange Ladder — `topology_c_ladder.svg`
Two concentric rings joined by three gated rungs (one is a jump-only
soft gate).
- Decision points: 5 · Gates: 4 · Authored routes: 14–16
- Pros: richest combinatorics per authored segment; rungs make
  crossover choices constant; inner ring = safe/cheap grammar, outer =
  fast/risky; the jump rung is the gateway-upgrade showcase.
- Cons: hardest to keep legible; needs the risk grammar enforced
  strictly or players get lost.

### D. Spiral Annex — `topology_d_spiral.svg`
Rings share ONE common start straight and peel off progressively
(annexed loops of increasing size), plus one gated cross-cut.
- Decision points: 3 · Gates: 3 · Authored routes: 7–9
- Pros: the shared start straight becomes an ever-thickening ghost
  river — strongest single image in any option; trivially extensible
  (each new ring is DLC-shaped).
- Cons: least route variety per gate; long rings raise lap times, so
  income normalization matters most here.

**Recommendation: B (Clover) as the structure, stealing C's jump rung as
the gateway-upgrade moment between two petals.** Clover matches the
"one growing place" fantasy, keeps junctions legible (all charges happen
at the hub), scales by adding petals, and its hub is the ghost-overlap
showcase. A (Pretzel) is the right *prototype* scope — it's B with one
petal, so nothing is thrown away.

## 5. Route identity & discovery UX

- **Route ID = canonical ordered edge list** (never a junction bitmask —
  breaks on 3-way junctions and skipped junctions). Interned string key.
- Mid-lap, a **trie over authored routes** tracks the candidate set;
  the first disambiguating edge = "route locked in" UI beat; fleets of
  eliminated candidate routes fade slightly.
- Signed line-crossing detection gives double-back handling free:
  backward crossing of the last edge pops it; any other backward
  crossing dirties the lap (invalid at close).
- Route log entries: full card / silhouette+clue / counter, plus per-gate
  exhausted badges. Discovery fanfare on lap completion through a novel
  authored combination.

## 6. Economy integration

- **Income is per-second normalized**: payout_per_lap = rate × par_time,
  so route length is income-neutral and no route strictly dominates.
- Multipliers stack multiplicatively on top: **risk tier** (harder branch
  = richer, per the grammar), **ability premium** (upgrade-gated routes
  pay more — the upgrade's ROI), **discovery order** (later routes have
  higher base rates).
- **Mastery medals per route** (bronze/silver/gold PB thresholds vs par):
  permanent +10% / +25% / +50% to that route's fleet. Your PB *is* your
  ghost, so mastery bonuses read as "your best ghost earns what it
  deserves". Set bonus: all routes through a gate discovered → gate-wide
  multiplier (never leave a completed tier unrewarded).
- **Pricing:** gates at 10–20× current income/s-scale (the tuned-economy
  wall at 25–35 min is exactly where gate 1 should land); the gateway
  Jump Kit at 20–30×. A gate should repay itself in 15–30 min of the new
  routes' ghost earnings.

## 7. Technical architecture (from the Godot research)

- **Author roads as Path2D/Curve2D centerlines**; bake surface + border
  polygons via `Geometry2D.offset_polyline(tessellated_points, half_w,
  JOIN_ROUND, END_ROUND)` in a @tool script. Junctions merge visually by
  flat-color overdraw in two z layers (all borders below all surfaces) —
  no polygon unions needed.
- **No Area2D checkpoints in the network.** Analytic segment-crossing
  tests (`Geometry2D.segment_intersects_segment` on the car's per-tick
  movement) — tunnel-proof at any speed, signed direction free, and the
  same code path validates ghost recordings headlessly.
- **Gates** = StaticBody2D barrier + visual; open via
  `set_deferred("disabled", true)` (never mid-flush); purchased state
  lives in Bank, gates subscribe.
- **Resources** (all .tres, honoring hard rule 4): `TrackNetworkDef`
  (segments, gates, routes, widths), `SegmentDef` (id, endpoints,
  Curve2D), `GateDef` (id, blocked segment, price), `RouteDef` (id, name,
  edge_sequence, par_time, risk_tier).
- **RouteTracker** node consumes crossing events, owns the lap-edge
  accumulator and trie; emits `route_lap_completed(route_id, time)` /
  `route_discovered(route_id)`. Unit-testable headless with a scripted
  position sequence.
- Save additions: per-route {PB, recording, fleet size, medals},
  purchased gate ids, discovered route ids.

## 8. Build plan

1. **Prototype (branch `proto/gate-network`)**: Pretzel-lite — current
   ring + ONE gated chord = 2 authored routes. Proves: line-crossing
   route detection, per-route PB/recording/fleet in Bank, gate purchase
   in GARAGE, route discovery toast. No visuals beyond a barrier.
2. **Slice: route log UI** (cards, silhouettes, counter).
3. **Slice: Path2D road pipeline** (replace rectangle roads; needed
   before petals — hand-rect authoring won't survive curved petals).
4. **Slice: Clover petal 1** (theme + risk grammar + mastery medals).
5. Petals 2–3, Jump Kit gateway moment, knowledge route, exhausted
   badges.
