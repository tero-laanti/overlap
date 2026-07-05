# Research: gate networks, route discovery & economy (2026-07-05)

Agent research report, lightly trimmed. Actionable distillation lives in
docs/GATE_NETWORK.md — this file preserves the reasoning and sources.

## 1. Ability-gated world graphs (metroidvania theory)

- **Design the dependency graph before the road layout** (Boris the
  Brave's lock-and-key survey; GMTK's Boss Keys method). A road network
  can feel spatially rich yet be progression-linear — the mission graph
  exposes "how little choice there really is." Nodes for Overlap2: gates
  (locks), money + car upgrades (keys), routes (rewards).
- **Hard vs soft gates.** Hard gate = exactly one resolution (purchase).
  Soft gate = bypassable by skill or alternate resource. Soft gates
  create sequence-breaking joy; purchase-only networks degenerate into a
  shop menu. Upgrade-gated branches (ramps, rough surface) are natural
  soft gates: let a skilled driver squeak through early at a lap-time
  penalty.
- **Gateway abilities vs keys** (Silksong analysis): early abilities open
  1–2 doors each; one mid-game "gateway" ability opens many areas at
  once. Translate: early gates open one route each; one mid-game upgrade
  (jump ramps) retroactively activates branches in 3–4 places — the
  best "holy crap" moment available.
- **Concertina pacing:** alternate tight stretches (one obvious next
  gate) with loose stretches (2–3 affordable options). Never exactly one
  forever; never five at once early.
- **Legibility without map spoilers** (Hollow Knight rule): visible-but-
  locked passages appear on the map once seen; secrets never do. Closed
  gates should be physically visible from the road; the road beyond is
  revealed only by driving. Telegraph which ability a soft gate needs
  diegetically and unsubtly (Outer Wilds GDC lesson).
- **Knowledge as the free fourth key** ("metroidbrainia": Outer Wilds,
  Tunic, Animal Well): reserve 2–3 routes unlocked purely by realizing a
  combination exists — zero cost, discovery feels like the player's own
  genius.

## 2. Combinatorial content & discovery-collection mechanics

- **The collection log is the endgame screen.** Pokédex grammar:
  discovered = full-color card; hinted = silhouette/???; unknown = only a
  total counter ("14/23"). The counter turns anxiety into a puzzle.
- **Tiered hints:** Doodle God drips a free hint on a timer when stuck;
  Little Alchemy marks elements with no remaining undiscovered
  combinations — a negative hint that prunes search space. Overlap2:
  billboard hints after N stuck laps + a gate-"exhausted" badge once all
  its routes are found (cheapest, highest-value feature in this report).
- **Discoverable vs aspirational ratio:** the huge-aspirational-tail
  model (Doodle God 249, Little Alchemy 720 elements, most never found
  unaided) fits hint-monetized mobile, not a game this size. Target:
  ~70% of routes findable through normal play, ~25% deliberate
  experimentation, ~5% devious. Forza Horizon 6's unrewarded 700-road
  discovery tracker is the cautionary tale: always pay out discovery
  tiers.
- **Discovery must happen through play** (Mini Motorways postmortem
  theme): a route is discovered the moment a lap completes through a
  novel combination — fanfare — never by tapping a menu.

## 3. Route identity: beating the 2^B junk problem

- **The oatmeal problem** (Kate Compton): 10,000 mathematically unique
  bowls of oatmeal, perceptually identical. Don't count every
  graph-distinct circuit as a map — only authored combinations.
- **OutRun is the canonical solution:** 15 stages in a binary-branch
  pyramid, 16 routes; every branch changes theme, right is always
  harder, each terminal has its own ending. Steal: every branch changes
  ≥2 of {theme, hazard/surface profile, payout character}; keep a
  legible difficulty grammar.
- **Collapse trivia into shortcut variants** of the same route (affects
  lap time/PB, not route identity). Mario Kart's R/T variants show reuse
  works only when the variant meaningfully changes obstacle approach.
- **Route knowledge is content** (Burnout Paradise: 8 finish lines,
  knowing the best road is the skill economy). Equal-length routes
  should still demand different lines/setups to justify separate PBs.
- **Target count: 12–16 meaningfully distinct routes, ceiling ~20**
  (anchors: OutRun 16, Mario Kart 16–32, TrackMania campaign 25).
  Network shape: ~5 gates, 4–5 binary decision points, theoretical
  ~24–32 combos with the excess folded into variants.

## 4. Economy interaction

- Kongregate idle-math anchors: generator units ×1.07–1.15/unit;
  successive tiers ~an order of magnitude apart; prestige doubling costs
  3–4× (AdCap) to 128× (Egg Inc). "New area = 10–20× income" sits
  comfortably between tier and prestige beats. Hill Climb Racing (closest
  cousin: coins buy stages) escalates stage prices super-linearly and
  each stage raises earning ceiling — exactly the gate role.
- **Per-lap vs per-second: normalize per second.** If long routes
  dominate income/second, every other route becomes dead content.
  Differentiate with multiplicative bonuses: risk tier (harder branch =
  richer), ability premium (upgrade-gated routes pay more), discovery
  order (later routes have higher base rates).
- **Route mastery: TrackMania medal ladder** (bronze/silver/gold/author).
  Map to per-route PB thresholds granting permanent fleet multipliers
  (+10/+25/+50%). Uniquely honest in Overlap2: the PB lap literally IS
  the ghost. Add set bonuses for completing all routes through a gate.
- **Pacing advice (Kongregate): progress should be bumpy.** Gates are
  the walls; a new route's fleet is the burst. Don't smooth it.

## Sources

Boris the Brave lock-and-key dungeons · GMTK Boss Keys + Silksong world
design · Thinky Games metroidbrainia survey · GDC Outer Wilds
curiosity-driven design · Pokémon Sun/Moon UI breakdown (Space Ape) ·
Doodle God / Little Alchemy 2 design analyses · Death is a Whale
completion-rate data · Steam FH6 road-discovery complaints · Mini
Motorways postmortem (Disasterpeace) · Kate Compton "So you want to
build a generator" · Emily Short "Bowls of Oatmeal" · StrategyWiki /
HG101 OutRun · Mario Wiki course variants · Burnout Paradise race design
· Kongregate "Math of Idle Games" I–III · Hill Climb Racing wiki ·
TrackMania author-medal guides.
