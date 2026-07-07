# Handoff — for the next agent (updated 2026-07-07 by Claude Fable 5)

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
11. Next: petal 3 (harbor) per docs/MAP_DESIGN.md §8 — the visual
   foundation is in, so author it pretty from the start (navy/rust/
   crane-yellow palette per MAP_DESIGN §7). Then Jump Kit gateway
   moment (+ cliff washout jump spot), coast linker + grand tour,
   gate-exhausted badges.

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
