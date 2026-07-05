# Handoff — for the next agent (written 2026-07-05 by Claude Fable 5)

You have fresh context. This file is your fastest path to being useful.
Read in order: AGENTS.md (rules — non-negotiable), ROADMAP.md (state),
this file (next steps), and when you touch the gate network,
`.worktrees/design/docs/GATE_NETWORK.md` + `docs/research/*` on the
`design/gate-network` branch.

## Where the project stands

Main is through Slice 5 plus most of Slice 6: offline earnings are DONE
and precisely verified (income × min(elapsed, 8h cap) — I tested with a
backdated save: exact to the second). Drift trails are in and
functionally verified (both tires emit points headlessly). The car feel
on main is now DRIFT-HEAVY (grip 6.0, drift_grip 0.65) — folded in from
a variant branch by an external LLM session, then reviewed by me. The
last three commits (2f1e3e3, 1511357, cb7f9ff) are that fold + review;
all verified green: full probe loop, laps 6.90/6.61s, income 3.02/s,
zero script errors.

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
4. Next, in order: route log UI, then the Path2D road pipeline
   (research doc has the exact recipe), then Clover petal 1.

## Verification workflow (mandatory before any commit)

- Boot: `godot --headless --path . --quit` → zero errors.
- Full loop: `rm -f "$HOME/Library/Application Support/Godot/app_userdata/Overlap2/save.dat"`,
  `touch .../autopilot.flag`, then `godot --headless --path .` (probe
  drives 2 laps → earns to $110 → buys ghost+upgrade → clean upgraded
  lap → watches income → auto-quits, ~80s). Grep the output for
  `[PROBE] LAP`, `bought ghost_slot=true`, `done`. Remove the flag file
  after — if it lingers, the next human play session gets hijacked by
  the autopilot.
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
  diagrams in .worktrees/design/docs/diagrams/).
- Economy feel checkpoints: first 90 seconds should feel generous; the
  10-ghost ×2 milestone should be looming by minute 15 (knobs in
  data/economy.tres — see docs/DESIGN_NOTES.md "Tuned economy v1").
- Godot 4.7 bump waits for 4.7.1 (shared brew binary with other
  projects).
