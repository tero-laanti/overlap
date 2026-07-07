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

## Roguelite rounds + rival onboarding (2026-07-07 brainstorm — user, undecided)

Two linked ideas. Both rub against the scope fence (VISION: no
opponents/AI in v1) and the tuned cold start (first buy at 20–40 s,
DESIGN_NOTES) — refine against those before choosing.

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
