# Idea inbox

Unrefined ideas worth keeping. Not commitments. Move into VISION/ROADMAP
only when chosen; delete when rejected.

## Track expansion (2026-07-05 brainstorm — user excited, undecided)

The game is called Overlap: expansions should share road, not add menus.

1. **Loop annexation** — new loops graft onto the existing circuit and
   share a segment with it. Old fleets keep their loop; shared straights
   become ghost rivers. One growing place instead of a track list.
2. **Ghost transit map** — track is a road network; a "track" is a
   recorded route (checkpoint sequence) through it. Each route = a colored
   ghost line; late game reads like a subway map of your laps.
3. **Purchases transform the track** — bridges/shortcuts/boost pads edit
   geometry. Old transform-replay ghosts visibly drive the obsolete line;
   re-recording to exploit new geometry is the incentive.
4. **B-side mutations** — reversed / mirrored / night / rain variants of
   existing geometry, each with its own PB and fleet (IGTAP's move).

Architectural implication adopted now: define tracks as checkpoint routes
over composable road geometry, not sealed one-off scenes.

## ~~Full track relayout~~ CHOSEN 2026-07-07 → docs/MAP_DESIGN_V2.md
## (15 s hub, design-all build-hub-first, full save wipe)

## Roguelite rounds + rival onboarding (2026-07-07 brainstorm)

Two linked ideas. Item 2 (rival onboarding) CHOSEN 2026-07-10 →
ROADMAP slices 9–11: the ladder (AMBER/COBALT/ONYX), then resident
rivals per zone gating each route's fleet. The VISION scope fence was
consciously amended (replay rivals in, live AI out). Item 1
(pick-1-of-3 rounds) remains undecided — prestige-as-seasons and
session contracts are still open homes for the draft moment.

1. **Pick-1-of-3 rounds** — after a "round" of sorts, choose one of
   three offers: a new route, extra rewards, a whole new track, etc.
   Adds decision texture to the current buy-the-next-gate ladder.
   - Constraint: full roguelike resets fight the core fantasy — ghosts
     ARE the persistence, the filling track IS the progress bar. Keep
     accumulation; borrow only the draft moment.
   - Three homes for the draft, no resets required:
     - **Prestige as seasons** — the planned prestige layer ends a
       "season"; the reward is a pick-1-of-3 permanent perk instead of
       a flat multiplier.
     - **Session contracts** — pick 1 of 3 challenge cards ("gold on
       Dune Bend", "5 clean cliff laps"); completing pays a chunky
       bonus. Serves the keep-driving-alive guard; zero geometry work.
     - **Mutation drafts** — the 3 cards are B-side variants of owned
       roads (item 4 above); picking one unlocks it permanently with
       its own PB + fleet.
   - Tension: random draft order vs authored gate pacing (concertina,
     ShopPacing, gates fence visible asphalt). Drafts should offer
     rewards ON owned geography, not replace the gate ladder.
   - Open: what ends a "round" — beating a rival, a timed session,
     N laps, an income milestone?

2. **Rival onboarding** — the game opens as a race against one
   opponent; beating them unlocks your first ghost, and only then does
   passive income start (before that, you just drive to improve).
   - Nearly free with existing tech: a rival is an authored
     LapRecording replayed by the existing Ghost scene (opaque +
     named instead of translucent). No AI, no collision — hard rule 5
     survives. DevCalibrate bot runs already produce exactly these
     recordings, and medals already encode "silver = the bot, gold =
     beat the bot" — a rival makes that bot VISIBLE and beatable
     instead of an abstract par.
   - Generalizes: each new petal/route could ship a resident rival
     ghost; beat it to claim the route's fleet (or its medal).
     Discovery toast → rival intro is a strong beat per zone.
   - Risk: hard-gating ALL income on a win breaks pillar 4 ("every
     session ends better than it started") if the player can't win.
     Mitigations: first rival paces ≈ bronze par; or active-lap income
     trickles immediately and only the FLEET is gated behind the win.
   - Requires a conscious amendment to the VISION scope fence if
     chosen.

## Non-Euclidean biome (2026-07-10 brainstorm — user: "keep in mind for the future")

Impossible-space tricks via **teleport seams**: turn left and re-enter
from the right, a 180° hairpin that exits onto a different track, a
straight that loops onto itself. Feasible because top-down + follow
camera means the player only ever sees one screen radius — a seam is a
`SeamSegment` pair (two line segments + translation-only transform;
matching road headings so the non-rotating camera can't tell) that
teleports car, velocity, and anything replaying through it.

- Plumbing mostly exists: splash reset is already a mid-lap teleport
  RouteTracker ignores; drift trails already break per stint; ghosts
  stay dumb (a recording just contains a position jump — add a seam
  flag on the sample so replay snaps instead of lerping a streak).
- Art cost, not code cost: seam mouths must look identical within a
  camera radius, and world-space shaders (mottle/water) shift phase at
  the jump — put every seam under cover (tunnel/canopy at z+1, gantry-
  beam precedent) and it's trivially clean + becomes the biome's look.
- Design fit: V3 is about legibility; non-Euclidean is deliberate
  illegibility. Contain it — a late "Mirage/Fold" island where the
  gimmick IS the island (its per-island minimap being visibly wrong
  advertises it), or a single secret route elsewhere.
- Verify DevDriver waypoint-chasing survives a teleport before
  building on it.
