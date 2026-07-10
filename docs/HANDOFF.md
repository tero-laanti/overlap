# Handoff — for the next agent (updated 2026-07-10 by Claude Fable 5)

You have fresh context. This file is your fastest path to being useful.
Read in order: AGENTS.md (rules — non-negotiable), ROADMAP.md (state),
this file (next steps), and when you touch the gate network, the design
doc on the `design/gate-network` branch (remote-only now — no local
worktree; `git show origin/design/gate-network:docs/GATE_NETWORK.md`).

## Where the project stands

Main is through ROADMAP slice 7 petal 2 (THE CLIFFS) plus the visual
identity pass: 7 authored routes across the ring, island chord, dune
petal, secret forest road, and the cliff ladder; per-route PBs, fleets,
and mastery medals; save v3; flat-vector look with water/mottle shaders
and photo-mode tooling. The numbered list below is the full history —
items 1–10 are DONE, item 11 is next. A 2026-07-07 code-review pass
(multi-agent, adversarially verified — see that session's report)
landed on top of it: atomic save writes, shop buttons unfocusable,
route certification requires owned gates (cliff-gate flank exploit),
crossing-line inside margins, docs refreshed, Bank/DevProbe split under
the line ceiling. NOT play-verified — Godot was unavailable on the
machine that made those fixes; run the probe loop before building on
them.

## Highest-priority next steps, in order

1. ~~Get the human's feel sign-off.~~ DONE 2026-07-05: human played and
   signed off the feel as-is. Follow-up fixes landed on main: drift
   trails are per-stint Line2Ds (fade after 4 s; fixes the
   stint-connecting streak) and also draw from keyless sideways scrub
   (threshold drift_trail_min_lateral_speed = 250); road-edge walls and
   island collision were replaced by slowing grass (car queries the
   RoadSurface Area2D, physics layer 2; grass knobs in
   starter_car.tres). Sand/real-wall track elements are a wanted
   follow-up. Walls remain at the world edge only.
2. ~~Cherry-pick the surviving polish work.~~ DONE 2026-07-05: ghost
   tint variety, garage milestone label, and HUD next-purchase hint
   cherry-picked onto main (one trivial conflict in ghost_fleet.gd);
   probe loop green. Branch `polish/quality-pass` and its worktree
   deleted.
3. ~~Build the gate-network prototype.~~ DONE 2026-07-05, folded into
   main (see ROADMAP slice 7): TrackNetworkDef/RouteDef/GateDef/
   CrossingLineDef resources + RouteTracker (analytic line-crossing,
   scenes/track/route_tracker.gd), per-route PB/recording/fleet in Bank
   (save v3, v2 migration verified), island gate in GARAGE, discovery
   toast. The chord sits at x=300 — NOT x=0 — because the start line is
   vertical at x=0 and a car descending a chord there would move
   parallel to it and never cross. Probe now covers the whole flow
   (BUY_GATE/DRIVE_CUT/WATCH_CUT phases). Human feel pass on the cut
   route + gate UX still pending.
4. ~~Route log UI~~ DONE 2026-07-05 (R key; cards/clues/counter; gate
   also hardened — wider bar + chord_mouth line in the cut's edges so
   grass-flanking validates nothing).
5. ~~Path2D road pipeline~~ DONE 2026-07-05: RoadSegment @tool scene
   bakes surface + grass hitbox from Curve2D centerlines; track01
   rebuilt drivable-area-identical (probe laps byte-identical). Curves
   are now just curvier centerlines.
6. ~~Clover petal 1~~ DONE 2026-07-05: sand petal + Dune Gate + Dune
   Bend/Twin Cut routes + mastery medals (economy.tres knobs; derived
   from PB vs par, never stored). NOTE: adding a petal widens the
   junction area, which sped up ring laps (~6.4s vs 6.9) — pars were
   recalibrated so probe-clean laps land silver. Twin Cut has never
   been driven; its par (5.8) is a guess — verify when someone drives
   it. Human feel pass on the petal curve pending. A debug save wipe
   lives in the GARAGE (debug builds only) and DevProbe resets through
   it every run.
7. Mastery/pacing pass DONE 2026-07-05 (human-directed): medals are a
   per-route purchase (GARAGE "Mastery:" rows), pars authored from
   DevCalibrate maxed-car runs (user://calibrate.flag — never together
   with autopilot.flag; rerun + re-author pars after ANY handling or
   catalog change), Top Speed capped Lv 3 so racing lines beat
   reflexes, GARAGE evolves via ShopPacing (upgrades by total levels,
   one gate at a time, mastery per discovered route), crossing lines
   extended over grass aprons so wide racing lines register. DevDriver
   (shared autopilot) brakes into sharp turns.
8. Island expansion 1 DONE 2026-07-05 (human-directed; geography doc:
   docs/MAP_DESIGN.md): water boundary with reset-to-road (lap void +
   SPLASH toast; RouteTracker ignores the teleport), land grown to
   ±2900 × -2700..1500, tree obstacles, and the Forest Run knowledge
   route — hidden SecretRoad revealed forever by crossing the line
   between the two golden trees at (-840/-480, -780). Secret RouteDefs
   never hint; counter-only until driven. Calibrator drives the forest
   THROUGH the gap (tests the trigger); DevDriver has per-route reach
   (120 for the gap). Grass decel now adds the car's acceleration so
   upgrades can't out-pull it. CAUTION: keep the Godot editor closed
   while agents edit .tscn/.tres — an editor save moved the Track node
   and null'd newer RouteDef fields this session (both fixed).
9. ~~Petal 2 (cliffs) + border/curb pass.~~ DONE 2026-07-06 (written
   by Claude Fable 5): the Cliffs live NE/N (the Woods squat the
   planned north-center — see MAP_DESIGN §9 for the two documented
   deviations). Cliff Gate ($900, rotated bar) forks off the ring's
   NE corner; hairpin ladder → lighthouse hairpin → north-shore esses
   → descent straight through the chord-mouth junction, which IS the
   at-grade X crossover (no new mouth on the top road). New systems:
   RoadSegment border layer (border polygon z=-1, ALL background
   polys pushed to z -4/-3/-2 — drift trails are z=0 Main-level
   siblings and stay above surfaces by tree order; do NOT raise any
   surface above z 0), rubble shoulders (physics layer 4, near-stop;
   `rubble = true` on a segment turns its border strip into the
   hitbox; decel includes acceleration like grass), WallSegment
   (@tool StaticBody2D ribbon — first real walls). Routes: climb
   (par 16.0, payout 38) and high_ring (par 18.2, payout 41.5,
   discovered by turning east at the X); maxed bot lands silver on
   all 7 routes. Human feel pass on the hairpins/rubble PENDING —
   flag any handling complaint before touching starter_car.tres.
   Gotchas hit: (a) crossing lines between ladder rungs must NOT
   span the full rubble apron — rungs are 340px apart and aprons
   (±175) overlap between them, so a full-apron line would double-
   fire from the neighboring rung (cliff_climb spans road+15px
   only); (b) the descent ends at (300,-560) so its square cap
   seals into the top-road/chord junction — move it and the X
   asphalt gaps; (c) climb requires BOTH cliff_gate and island_chord
   (descent exits through the chord; concertina pricing means the
   chord is always owned first anyway).
10. Visual identity pass DONE 2026-07-06 (human-directed, "do it
   all"): flat-vector direction, NO tile packs (they fight the
   centerline-baked road pipeline). Water/mottle/checker shaders in
   assets/shaders/ (world-space via MODEL_MATRIX varying), zone
   underlays, RoadSegment dash bake, gantry/pit/garage dressing,
   layered vector car/ghost/trees, FollowCamera (zoom + shake),
   dust/splash CPUParticles. THE Z CONTRACT (don't break it):
   water -4, grass -3, underlays/island -2, road borders -1,
   surfaces/props/trails/cars 0 (tree order), gantry beam +
   lighthouse fan +1. Drift trails are Main-level z0 siblings —
   raising any surface above z0 hides them. NEW TOOL: photo mode
   (touch user://photo.flag, run WINDOWED godot; flies a camera over
   12 authored viewpoints, saves user://dev/photo_*.png, quits) —
   this is how art passes get verified on macOS where headless can't
   screenshot. Back up the human's save around photo runs too:
   loading grants offline earnings and the 5s autosave rewrites the
   file. Camera zoom/shake knobs await a human feel pass
   (scenes/car/follow_camera.gd exports); car HANDLING untouched
   (probe lap times identical pre/post).
11. Esc overlay + audio pass DONE 2026-07-07 (human-directed): Esc
   menu (non-pausing — the idle world keeps earning; buttons/sliders
   FOCUS_NONE per the shop lesson), settings.cfg owns device prefs.
   Audio: buses in default_bus_layout.tres, ALL SFX synthesized by
   tools/gen_sfx.py (rerun + commit WAVs to tweak), CarAudio reads
   car state via is_on_road_now()/is_sliding(), GameAudio wires
   Events stingers, CC0 music + engine sample per
   assets/audio/SOURCES.md. GOTCHA: headless audio players leak
   playback objects at exit (dummy driver never mixes) — both audio
   nodes go dormant under headless; keep it that way. WAITING ON THE
   HUMAN: mix levels, synth-vs-sampled engine A/B
   (use_sampled_engine on CarAudio), music taste, plus the older
   cliffs-hairpin and camera zoom/shake feel passes.
12. ISLAND V2 SLICE 1 DONE 2026-07-07 (human-directed: "a 5 second
   lap doesn't feel race-y"): the game now runs the ~15 s GP-style hub
   (scenes/track/track02, docs/MAP_DESIGN_V2.md — read it before any
   geometry work; MAP_DESIGN.md is superseded for geography but its
   rules still govern). Save v4 wipes older saves on load (approved).
   track01 and its petals are DELETED — the cliffs/dunes/forest
   content returns re-adapted per V2-3/4; their designs live in
   MAP_DESIGN_V2 §3 and git history (cliffs: commit 5812e53). The
   human's pre-wipe save is parked at
   ".../Overlap/save.dat.track01.bak". Probe/calibrator/photo all
   retargeted; calibrated pars ring 12.4 / cut 9.1. Bake gotchas: a
   CLOSED centerline bakes as a filled blob (offset_polyline returns
   an annulus, RoadSegment keeps the largest polygon — split loops
   into open segments at zero-curvature points); Curve2D point_count
   larger than the data invents a phantom point at the origin.
13. ISLAND V2 COMPLETE 2026-07-07 (V2-2..V2-5 in one session,
   human-directed "let's do them all"): minimap (bounds derive from
   the track's Grass polygon — annexes appear automatically; secret
   roads stay off it until revealed), dunes west (Dune Bend +
   Sand Cut), cliffs+woods north (Lighthouse Climb, High Ring,
   secret Forest Run — the descent crosses at the chord mouth, ONE
   X, junction-spacing clean), harbor east (Container Run, stop-go
   maze, container walls = WallSegment ribbons, navy/rust palette).
   Gates ladder: island 120 → dunes 250 → cliffs 900 → harbor 2200.
   All pars from calibration runs; probe covers the full five-gate
   loop. GOTCHAS this session: (a) closed-loop centerlines bake as
   filled blobs — split into open segments at zero-curvature points;
   (b) Curve2D point_count beyond the data invents a phantom origin
   point; (c) gate.gd requires its CollisionShape2D child be named
   exactly "Shape"; (d) Bank.reset_profile now emits
   Events.profile_reset — stat consumers (car) must recompute on it;
   (e) sliver dashes at segment ends fail triangulation (guarded).
14. RIVAL ONBOARDING DONE 2026-07-10 (chosen by the human; ROADMAP
   slice 9, VISION scope fence consciously amended): the game opens
   as a race against AMBER — an opaque named ghost replaying an
   authored base-car bot lap (data/rivals/ring_rival.tres, 16.38 s =
   bot pace × RIVAL_HANDICAP 1.07) synchronized to every lap start.
   ghost_slots now START AT 0; beating the rival's time on the ring
   hires ghost #1 and only then does passive income exist (active
   laps pay from lap one — pillar 4). Shop hides Hire Ghost and the
   HUD hint shows the rival objective while slots == 0. Existing
   saves grandfather via an invariant, not a version bump: slots >= 1
   with empty rivals_beaten ⇒ mark ring_rival beaten (the win is the
   only 0→1 path). New pieces: RivalDef + RivalRacer
   (scenes/ghost/), Events.rival_beaten, Bank.mark_rival_beaten,
   Ghost.playing flag (parks the rival on the grid), DevRivalRecord
   (user://rivalrecord.flag — wipes to base car, drives the ring,
   writes the slowed .tres; RERUN + RECOMMIT after any base-car
   handling change, like calibrate). GOTCHA from this session: an
   aborted read_into (typed-array ternary crash) half-loaded a save
   that a later autosave then rewrote with rivals_beaten=[] — the
   invariant-based grandfather self-heals exactly this; prefer
   invariants over key-presence defaults for save migrations. Human
   feel pass PENDING: is AMBER's pace right for a first session?
   Generalization parked in IDEAS.md: resident rival per zone, beat
   it to claim the route's fleet/medal — discovery toast → rival
   intro is the strong per-zone beat.
15. ONBOARDING V2 DONE 2026-07-10 (human-directed: "too much going on,
   everything unlocks too fast, AMBER too easy"; ROADMAP slice 10,
   DESIGN_NOTES "Onboarding v2"): THREE rival tiers — AMBER 15.93 →
   COBALT 15.06 → ONYX 14.28 — each authored as the bot at a real car
   spec × small handicap (3-stage DevRivalRecord; reaching the spec
   beats the tier). Each win ×2 on ACTIVE lap payouts (economy
   rival_beaten_multiplier; active_lap_multiplier is now 1.0 — the
   ladder IS the early income curve); ONYX unlocks ghosts/idle. The
   GARAGE is a building: reveals at $50 (economy garage_unlock_cash),
   shop opens only inside GarageZone (track scene), sells upgrades
   only until ghosts exist (ShopPacing gates gates/medals; Hire Ghost
   row hidden at slots 0). Progressive reveal: TrackReveal +
   zone_<gate_id> node groups hide locked annexes (visuals AND
   collision); next-on-sale gate previews its road at alpha 0.22;
   minimap only draws visible segments (first build DEFERRED past
   TrackReveal's deferred sync — both queue at ready, tree order
   matters) and only the on-sale gate pin. Save grandfather is
   invariant-based: slots >= 1 ⇒ all ONBOARDING_RIVALS + garage
   (bank_save.gd — keep that const in sync with main.tscn's ladder).
   Probe now drives the whole arc (buys the ONYX spec from lap
   earnings mid-ladder). Human feel pass PENDING: ladder pacing.
16. RESIDENT RIVALS DONE 2026-07-10 (human-chosen; ROADMAP slice 11):
   rivals moved into TrackNetworkDef.rivals (order matters — it's the
   ladder order per route); RivalDef gained required_gate +
   hires_first_ghost. ONE rule in Bank drives everything:
   is_rival_active (gate owned + earlier same-route tiers beaten) and
   is_route_fleet_active (no standing rival on the route → fleet
   earns; BankIncome and GhostFleet both consult it). Residents JADE
   (cut) / SIENNA (dune) / SLATE (climb) / RUST (harbor) are authored
   at each zone's arrival spec by DevRivalRecord (now drives every
   route; keep its STAGES, bank_save's ONBOARDING_RIVALS +
   RESIDENT_RIVALS, and track02_network.tres rivals array in sync).
   Gate purchase toasts the resident intro; beating it rolls out the
   fleet (residents do NOT grow the ×2 ladder multiplier). Save v5;
   v4 loads grandfather residents on routes that already had PBs.
   Multiple standing rivals all park on the start grid (they overlap
   if you stack unbeaten residents — rare, cosmetic, unfixed). Human
   feel pass PENDING: resident pacing per zone.
17. FLEET LIVERIES + JUMP KIT DONE 2026-07-10 (human-directed): each
   route's fleet wears RouteDef.ghost_color (Ghost.set_livery paints
   the shell; per-clone variation is alpha+lightness cycles). Fleets
   held by a standing rival do NOT spawn (the human explicitly
   rejected a dimmed preview fleet — the fleet is the prize);
   Bank._on_ghost_lap_completed keeps a belt-check anyway. Keep
   GhostFleet/BankIncome/Bank in agreement via is_route_fleet_active.
   Jump Kit: $1500 (economy.jump_kit_cost),
   offered once harbor_gate owned (ShopPacing.jump_kit_offered),
   Bank.jump_kit_owned in the save (no version bump — key default).
   Physics layer 5 = jump_ramp; the car point-queries it like
   road/water/rubble and goes ballistic for CarStats.jump_air_time
   (0.45 bare / 0.75 kit) — airborne is a BYPASS at the top of
   _physics_process, grounded handling untouched (probe lap times on
   old routes identical). Pier + canal geometry in track.tscn (all in
   zone_harbor_gate, so reveal + collision-disable come free); Canal
   Runner route (edges west/harbor_mouth/pier). The canal splash is
   the kitless fail (normal water reset). Cliff washout + dune crest
   jump spots from MAP_DESIGN §4 are NOT built yet — the kit
   "activates three places" only when those land.
18. ARCHIPELAGO PIVOT 2026-07-10 (human-directed; READ
   docs/MAP_DESIGN_V3.md BEFORE ANY MAP WORK): the v2 mega-island is
   dead — T-junction annexes killed momentum and route identity was
   illegible. V3 model: small clover islands (one base loop + ≤2
   variants + ≤1 secret each), junction grammar is canon (fork
   straight-on ≤45°, merge tangential ≤30°, never into corners),
   bridges between islands are TRAVEL not lap ingredients. V3-1 built:
   Home = ring + dune (T1 straight-on fork, tangential riser merge) +
   forest secret; chord/cliffs/harbor stripped (their proven geometry
   returns as Islands 2-3 — see git history for curves); save v6
   drops removed/reshaped-route PBs; Jump Kit off sale until V3-2
   makes it the Island-2 ticket (ShopPacing.jump_kit_offered is
   hardwired false — flip it there). Car jump physics + ramp layer
   stay, dormant.
19. FOREST RE-GRAMMAR DONE 2026-07-10 (human-directed, feel signed
   off "ok yeah it's better"): the forest forks off the RISER — the
   section the dune bypasses — so dune+forest in one lap is
   geographically impossible (grammar rule V3 §1.5: variants exclude
   by position, N loops = N+1 laps; unauthored combos silently void,
   so never leave one reachable). Golden gap relocated to the north
   corridor; exit is a long tangential on-ramp east onto the top
   straight. Forest par 16.3 (bot 17.16 — 2 s faster than the old
   hooked exit).
20. MASTERY REMOVED 2026-07-10 (human: "completely pointless as is" —
   agreed: doubly redundant since rivals made the bot beatable and a
   faster PB already earns more via lap frequency). Medals SURVIVE as
   free badges: tier still derived from PB vs par
   (economy medal_silver/bronze_factor), shown in the route log;
   NEW Events.medal_earned(route_id, tier) fires when a fresh PB
   upgrades the tier (Bank._on_best_lap_recorded compares tier
   before/after; PB only improves so it never downgrades) and plays
   the medal sting. GONE: RouteDef.medal_unlock_cost,
   Bank.medal_unlocked_routes + save key + try_buy_medal_unlock +
   medal_multiplier, ShopPacing.medal_offers, shop "Mastery:" rows,
   HUD mastery hint, economy medal_*_multiplier knobs, the medal term
   in ghost-lap payouts and income/s. Save stays v6 (dropped key just
   stops being read/written). Fleet income on identical PBs is now
   LOWER by the removed medal factor — expected, don't "fix" it.
21. Next: V3-2 the strait + Port island (shore ramps both ways,
   RouteTracker one-start-line-per-island, Port base loop from the
   maze/dock parts, garage pad #2, Jump Kit as the ticket) → V3-3
   pier/canal variant → V3-4 the Crag. Open V3 questions for the
   human are in the doc §5. Feel passes pending: rival pacing,
   camera zoom/shake, audio mix (dune fork + forest both signed off
   2026-07-10).

## Verification workflow (mandatory before any commit)

- Boot: `godot --headless --path . --quit` → zero errors.
- Full loop: BACK UP the human's save first, `touch .../autopilot.flag`,
  then `godot --headless --path .` (probe self-resets the profile,
  drives PB laps, buys ghost+upgrade, then all three gates in
  concertina order — island, dune, cliff — driving each new petal and
  watching every fleet; auto-quits, ~275s). Grep the output for
  `[PROBE] LAP`, `bought ghost_slot=true`, `bought cliff_gate=true`,
  `done`. Remove the flag file after — if it lingers, the next human
  play session gets hijacked by the autopilot — and RESTORE the save.
- Extend scenes/dev/dev_probe.gd with new phases when you add systems
  (that's how every slice here got verified — its phased scenario is
  the project's de-facto integration test).
- Crossing lines are DIRECTIONAL: RouteTracker's forward test is
  (b−a) × travel > 0. Author every line's a/b so racing-direction
  crossings are forward — a backward crossing dirties the lap and it
  silently never certifies (cost a calibration run in V3-1).
- Dev flags (user://, debug builds, never combined): autopilot.flag
  (probe), calibrate.flag (pars), rivalrecord.flag (authors the three
  data/rivals/*.tres from staged bot runs), photo.flag (windowed art
  check). All of them wipe or rewrite the save — back up the human's
  save.dat ONCE at session start to one canonical file and restore
  that same file after every dev run. Do NOT re-copy save.dat between
  runs: a 2026-07-10 session chained backups and briefly "restored" a
  dev run's save over the human's (caught by inspecting the file).
- Editor bridge (godot-mcp) needs the editor open; game-window
  screenshots don't work on macOS — the probe's user://dev/*.png frames
  are the substitute. If bridge calls time out, kill orphaned
  `godot-mcp/build/index.js` processes with PPID 1 (they squat port
  6008).

## Worktree/branch conventions

- Branch work lives in `.worktrees/<name>` (gitignored, dot-prefixed so
  Godot's scanner ignores it): `git worktree add .worktrees/x -b branch`.
- For parallel headless runs, temporarily set project.godot
  config/name to a unique value (isolates user://); revert before
  committing.
- After adding any new `class_name`, run `godot --headless --import .`
  once, and use the preload-const typing convention (AGENTS.md rule 8)
  in cross-script annotations.

## Open questions parked for the human

- Which topology for the full network (design doc recommends Clover;
  diagrams in docs/diagrams/ on the remote design/gate-network branch).
- Economy feel checkpoints: first 90 seconds should feel generous; the
  10-ghost ×2 milestone should be looming by minute 15 (knobs in
  data/economy.tres — see docs/DESIGN_NOTES.md "Tuned economy v1").
- Godot 4.7 bump waits for 4.7.1 (shared brew binary with other
  projects).
