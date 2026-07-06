# Overlap — The Island (map & track design)

Status: DESIGN — no code. Companion to `GATE_NETWORK.md` (design branch),
which owns the systems (gates, routes, discovery, economy). This doc owns
the *geography*: what the island actually looks like, what each zone
drives like, and the concrete route list. Written 2026-07-05 after a
research pass; sources at the bottom.

## 0. The one-sentence map

The game is one island. The hub ring you start on is the paddock at its
center; every purchase annexes more of the island's coastline, cliffs and
harbor into the road network, and every route you master pours more
ghosts onto the shared asphalt until the start straight is a river.

## 1. Design pillars (research → rules)

1. **Corners are punctuation.** Every corner needs a legible entry /
   clipping / exit; difficulty comes from tightening those, not from
   surprise. Long straights must never dump the player into a tight
   corner cold — put easier corners between a big straight and a hairpin
   (rational track-design guideline).
2. **Rhythm per zone, not per corner.** A zone should hold its speed
   inside roughly a ±30% band and have ONE signature rhythm (sweepers,
   stop-go, switchbacks). Variety lives *between* zones — this is also
   exactly the OutRun rule the network design already adopted.
3. **Landmarks anchor memory.** 1–3 landmarks per zone; roads exist to
   connect landmarks (rally level-design case). Landmarks double as
   route-log card art and map pins later.
4. **Suzuka's lesson:** a crossover buys a long, varied lap in a small
   footprint and is instantly iconic. In top-down 2D an at-grade X
   crossing is free — and two ghost rivers crossing through each other
   is the single best image this game can produce. The island gets
   exactly one, and it is *the* Overlap moment.
5. **Short lap ≠ small game.** Super Sprint kept whole tracks on one
   screen for readability; we keep the *hub* that tight (the heartbeat
   lap) and let length live in the annexes. Lap length is a ladder, not
   a slider.
6. **Surfaces are level design.** Rally case: the same corner is a
   different corner on sand vs tarmac. Each zone owns a surface behavior
   and therefore favors a different car stat — every zone is a showroom
   for one upgrade.

## 2. The island at a glance

```
        ~~~~~~~~~~~~~~~~~~~~~~~ open water ~~~~~~~~~~~~~~~~~~~~~~~~
     ~                        ⌂ LIGHTHOUSE                           ~
     ~                   ╭◜◝╮ hairpin ladder (3)                     ~
     ~                ╭──╯  ╰──╮   esses descent                     ~
     ~      CLIFFS ───╯        ╰───╮     (narrow, walls, rubble)     ~
     ~                             X ← at-grade crossover            ~
     ~   DUNES                     │                       HARBOR    ~
     ~  ╭─────────╮  ╔════════════╤╪╤═══════════╗   ╔═╦═╗ cranes     ~
     ~ ╭╯dune bowl╰─╮║  top road  ││chord       ║═══╣ ║ ║ container  ~
     ~ │ whale ribs │╠══╗         ││  (island)  ║   ╠═╩═╣ maze       ~
     ~ ╰╮ sweepers ╭╯║  ║ HUB     ││            ║   ║ ┄ ║ canal+JUMP ~
     ~  ╰────◟────╥╯ ║  ║ RING   ─╯│            ║   ╠═╦═╝ docks      ~
     ~   (petal 1)╚══╬══╩══════════╧════════════╬═══╝ ║              ~
     ~                bottom road → ══START══   ║     ║              ~
     ~        ╰────────── COAST ROAD (linker) ──╯─────╯              ~
     ~              shipwreck · beach · top-speed kinks              ~
        ~~~~~~~~~~~~~~~~~~~~~~~~~ water ~~~~~~~~~~~~~~~~~~~~~~~~~~
```

Water replaces the outer walls as the world boundary (beach strip =
heavy sand slowdown, then water = near-stop; no invisible walls
anywhere). World bounds grow from today's ~3.5k×2.5k px to roughly
**12k × 8k px**. The hub ring and petal 1 stay exactly where they are —
everything below annexes onto the existing network.

## 3. Zones

### HUB — Paddock Ring (exists)
- **Fantasy/landmarks:** start gantry, pit wall, the GARAGE as an actual
  building beside the start straight.
- **Rhythm:** flat-out heartbeat lap, ~6 s. Widest road (300). Stays the
  onboarding track, the PB-retry loop, and the segment every long route
  funnels through — the start straight is the ghost-river spectacle and
  must stay visually calm (no clutter) so the river reads.
- **Surface:** asphalt + grass aprons (as today).

### WEST — The Dunes (petal 1 exists; grows)
- **Fantasy/landmarks:** dune crests, whale ribs, the Dune Bowl (a long
  banked-feeling 180° sweeper).
- **Rhythm:** flowing constant-radius sweepers — the drift-heavy car's
  best feel. Petal 1 (Dune Bend) stays as the short inner loop; a second
  gate at its apex opens the **Outer Dunes**: a big sweeping circuit
  (apex ~x −3800) through the Dune Bowl rejoining the petal.
- **Surface:** sand shoulders instead of grass (wider, softer
  penalty — invites wide drift lines); soft sand pits as the hazard.
- **Upgrade showroom:** Grip. **Risk tier:** medium.

### NORTH — The Cliffs (petal 2; the technical zone)
- **Fantasy/landmarks:** lighthouse at the summit hairpin; cliff-edge
  road; a washed-out gap (Jump Kit spot #2).
- **Rhythm:** the anti-hub. Narrow road (220), a *hairpin ladder* (three
  stacked switchbacks climbing), the lighthouse hairpin, then a
  Suzuka-style esses descent. Slowest zone; ±30% band sits low, entered
  via a decel-friendly easy corner off the top road (pillar 1).
- **Surface/hazard:** first REAL WALLS (cliff face) on the outside;
  rubble strips (near-stop) instead of grass on the drop side. Risk =
  your lap, never the ghosts'.
- **The crossover:** the esses descent comes down and crosses the top
  road at grade (the X), continuing into the island interior to merge
  into the chord. Eastbound hub traffic and descending cliff traffic
  cross through each other here — the Overlap moment.
- **Upgrade showroom:** driver skill itself (medal country).
  **Risk tier:** highest → richest rate.

### EAST — The Harbor (petal 3; the rhythm zone)
- **Fantasy/landmarks:** gantry cranes, container maze, a ferry, the
  canal with the JUMP RAMP (Jump Kit spot #1, the gateway's home).
- **Rhythm:** stop-go. 90° container corners, one chicane pair, short
  bursts — acceleration is king. Several alley micro-shortcuts are
  *variants* (affect PB, not route identity — the oatmeal rule).
- **The dock straight:** the island's longest straight, down the pier —
  ends in a fast sweeper, never a hairpin (pillar 1).
- **Surface/hazard:** asphalt + hard container walls; oil slicks near
  the cranes (brief grip loss) as the risk element.
- **Upgrade showroom:** Acceleration. **Risk tier:** medium-high.

### SOUTH — The Coast Road (the linker)
- **Fantasy/landmarks:** beach, shipwreck, palm shadows.
- **Rhythm:** top-speed cruise with kinks — a breather zone connecting
  Dunes exit directly to Harbor entrance without touching the hub. This
  is the Clover "petal linker": expensive, late, and the enabler of the
  island-lap fantasy.
- **Upgrade showroom:** Top Speed. **Risk tier:** low risk, but long —
  pays via length premium.

## 4. Network authoring rules (additions to GATE_NETWORK.md §7)

- **Mid-edge crossing lines never sit on shared or crossing asphalt.**
  The X crossover works precisely because the top road's route identity
  is established by lines elsewhere (west/east road lines). Place every
  line at least one road-width away from any junction or crossing.
- **Junction spacing:** at ~1100 px/s a player needs ≥ 1.5 s between
  decisions → junction mouths on the same road at least ~1600 px apart.
  (Today chord mouth and the proposed cliff exit share the top road —
  the X-crossover routing exists to respect this.)
- **Every gate visibly fences asphalt you can already see** (Hollow
  Knight legibility rule) — barrier + a teaser stub of themed road
  before the fog. Gates get map pins once driven past.
- **Soft gates:** the canal jump is barely clearable pre-Jump-Kit at
  max top speed with a perfect line (sequence-break joy); the cliff
  washout and dune crest gaps are NOT clearable early (Jump Kit's
  "map explodes" moment activates three places at once).

## 5. Route table (authored; target 14 + reserve)

| # | Route | Path sketch | Gate(s) | Est. lap | Rate premium | Discovery |
|---|-------|-------------|---------|---------:|--------------|-----------|
| 1 | Grand Ring | hub ring | — | 6 s | 1.0× (base) | tutorial |
| 2 | Island Cut | hub W + chord | island_chord | 4.5 s | 1.0× | normal |
| 3 | Dune Bend | petal 1 + hub E | west_petal | 6 s | 1.1× | normal |
| 4 | Twin Cut | petal 1 + chord | both above | 4.7 s | 1.15× | experiment |
| 5 | Dune Circuit | outer dunes loop | outer_dunes | ~22 s | 1.2× | normal |
| 6 | Sandline | outer dunes + chord | outer_dunes + chord | ~18 s | 1.25× | experiment |
| 7 | Lighthouse Climb ✓ | cliffs → X → chord | cliff_gate | 16 s (par) | 1.4× (risk) | normal |
| 8 | High Ring ✓ | cliffs → X, turn E → hub E | cliff_gate | 18.2 s (par) | 1.35× | experiment |
| 9 | Container Run | harbor inner maze | harbor_gate | ~18 s | 1.25× | normal |
| 10 | Dock Tour | harbor + dock straight | harbor_gate | ~26 s | 1.3× | normal |
| 11 | Canal Runner | harbor w/ canal jump | harbor + Jump Kit | ~15 s | 1.5× (ability) | normal after kit |
| 12 | Washout Drop | cliffs w/ gap jump | cliff + Jump Kit | ~16 s | 1.5× | experiment |
| 13 | Coastal Grand Tour | dunes → coast → harbor → hub | coast_gate (+2 petals) | **~75–90 s** | 1.6× + length spectacle | normal (the trailer route) |
| 14 | The Commute | coast road out-and-back, minimal hub | coast_gate | ~35 s | 1.3× | **knowledge** (zero-cost realization) |
| R1 | Full Island | every petal in one lap | everything | ~2 min | 1.8× | authored epic, endgame |
| R2 | (reserve) | reverse-grammar or night variant | — | — | — | future |

Gates: `island_chord` ✓, `west_petal` ✓, then `outer_dunes` →
`cliff_gate` → `harbor_gate` → `coast_gate`, plus the **Jump Kit**
upgrade (not a gate — a garage purchase that soft-opens three places).
Six gates is one over the design target of five; the concertina survives
because outer_dunes and cliff_gate deliberately overlap in
affordability (a loose stretch), then harbor → coast is tight again.

## 6. Lap length — the ladder, and why longer is right

Today everything lives at 4.5–7 s, which is why it feels MVP-ey: one
rhythm, one screen, one heartbeat. Proposed ladder:

- **6 s** hub — onboarding, PB-retry tightness, ghost-river anchor.
- **15–26 s** petal routes — a "track" in the classic arcade sense;
  enough corners for a real racing line and for medals to mean lines,
  not reflexes (this is where most play happens mid-game).
- **35–50 s** two-zone combos — route knowledge becomes content
  (Burnout Paradise lesson from the research file).
- **75–120 s** grand tours — the idle-game showcase: one lap pays a
  celebratory chunk (`active_lap_multiplier` × a length-premium payout),
  and one PB upgrades a fleet that parades the whole island.

Why length is safe economically: income is already per-second
normalized (payout ≈ rate × par), so a long route is never strictly
dominant — it pays *chunkier*, which Kongregate's idle math actively
recommends ("progress should be bumpy"). Recording cost is trivial
(30 Hz × 120 s ≈ 3.6k samples). The real costs are: (a) a dead first
minute if a new player is stuck on a long route — solved because long
routes are late-game annexes; (b) mid-lap abandonment hurts more —
solved by the route log's mid-lap "locked-in" trie moment giving
feedback that the attempt is on course.

## 7. Readability at scale

- **Dynamic camera zoom** with speed (zoom out ~15% at top speed);
  petals were designed around today's zoom, the harbor maze needs it.
- **Minimap / island map screen** with fog-of-war: driven asphalt draws
  in full, seen-but-locked gates pin as icons, everything else is coast
  outline only (map grammar from the discovery research).
- **Zone palettes:** hub asphalt gray/white; dunes warm sand + terracotta;
  cliffs cold slate + lighthouse white/red; harbor navy + rust + crane
  yellow; coast turquoise water + pale sand. Borders/curbs land with the
  two-layer overdraw pass (petal 2 slice) and instantly de-MVP the look.
- **The start straight stays sacred:** widest, calmest, all routes
  funnel through it — the one place the whole economy is visible as
  traffic.

## 8. Build order (maps onto ROADMAP slice 7+)

1. **Cliffs (petal 2)** — biggest variety win (technical vs flowing),
   first walls + rubble surface, the X crossover, borders/curbs pass.
2. **Harbor (petal 3)** — stop-go rhythm, container walls, canal ramp
   authored (inert until Jump Kit).
3. **Jump Kit** — gateway moment; activates canal + washout + dune crest.
4. **Coast Road + Grand Tour + The Commute** — the island-lap payoff.
5. **Full Island epic + gate-exhausted badges + map screen.**

## 9. Open questions for the human

- ~~Water: hard stop or reset?~~ DECIDED 2026-07-05: reset to the last
  on-road position, velocity zeroed, lap voided. Implemented.
- NEW ZONE (human idea, implemented 2026-07-05): **the Woods** (NW) —
  scattered tree obstacles; two golden trees flank an invisible road
  mouth; driving the gap permanently unlocks the hidden **Forest Run**
  (the first knowledge route — counter-only until driven, then a full
  card). Pattern generalizes: SecretRoad + trigger crossing line.
- ~~Should the X crossover have a visual bridge?~~ BUILT at-grade
  2026-07-06, with two deviations from §3 (both because the Woods now
  occupy the planned north-center): (1) the cliffs live NE/N — the
  approach forks off the ring's NE corner, the ladder climbs the east
  side, the esses run the north shore above the woods; (2) the X is
  the chord-mouth junction itself, upgraded to a 4-way crossroads —
  the descent crosses the top road at grade straight into the chord,
  so no new mouth was added to the top road (junction-spacing rule
  respected by construction). Consequence: the descent also crosses
  the (hidden) forest road once, at grade, near-perpendicular at
  ≈(340,-1890) — topologically unavoidable, since the forest arc plus
  the top road enclose the pocket the chord sits in. No crossing
  lines are near it. The hub X stays the flagship overlap moment; the
  woods crossing is a quiet bonus that only exists once Forest Run is
  revealed.
- Night/weather variants as route *variants* or as a prestige-layer
  reskin? (Reserve R2.)
- Names: "The Island" needs a real name — it will be the save file's
  world and the route log's title.

## Sources

- Game Developer — [A Rational Approach To Racing Game Track Design](https://www.gamedeveloper.com/design/a-rational-approach-to-racing-game-track-design)
- Game Developer — [Racing Level Design: The Rally Case](https://www.gamedeveloper.com/design/racing-level-design-the-rally-case)
- Motor Sport Magazine — [Crossover circuits](https://www.motorsportmagazine.com/articles/single-seaters/f1/crossover-circuits/) · [RacingCircuits.info Suzuka history](https://www.racingcircuits.info/asia/japan/suzuka.html)
- [Super Sprint](https://en.wikipedia.org/wiki/Super_Sprint) single-screen readability · [art of rally](https://en.wikipedia.org/wiki/Art_of_Rally) top-down surface/theme variety
- In-repo: `.worktrees/design/docs/GATE_NETWORK.md`,
  `docs/research/route_discovery_design.md`,
  `docs/research/branching_track_tech.md`
