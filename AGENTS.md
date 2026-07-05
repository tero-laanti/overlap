# Overlap2

Idle/incremental top-down 2D racer. You drive laps; your recorded laps become
ghost cars that replay forever and earn passive income. Income buys upgrades,
cars, tracks, and more ghost slots. Concept: docs/VISION.md. Structure:
docs/ARCHITECTURE.md. Current work: ROADMAP.md.

## Tech

- Godot 4.6 (2D, GL Compatibility renderer). Installed binary: `godot` (4.6.2).
- Validate boot: `godot --headless --path . --quit` must exit clean, no errors.
- godot-mcp is available: use it to run scenes, take screenshots, and read
  output. Verify gameplay changes by running the game and observing, not by
  re-reading the code.

## Hard rules

These exist because Overlap 1 died from a 1244-line main.gd orchestrator.

1. **Main composes, never orchestrates.** main.gd instantiates scenes and
   connects signals. If it approaches 150 lines, logic is leaking in — move it
   to the scene that owns it.
2. **Every multi-step flow owns its own state.** Race flow, shop, prestige:
   each is a self-contained scene with its own state machine. Signals up,
   calls down, never bidirectional (a scene that emits to a parent must not
   also be method-called by that parent to drive the same flow).
3. **Exactly two autoloads.** `Bank` (currency, income math, upgrades owned,
   save/load — pure data, zero scene references) and `Events` (signal bus for
   cross-scene facts like `lap_completed`, `ghost_hired`). Never add a third.
4. **All tuning is Resources in data/.** Car stats, upgrade definitions, track
   params, economy curves. No gameplay constants inside scripts.
5. **Ghosts are dumb.** A ghost replays recorded samples by interpolation. No
   physics body, no collision with the world, no AI. If a ghost seems to need
   logic, the design is wrong — fix the design.
6. **300-line ceiling.** Any .gd file over ~300 lines gets split before more
   is added to it.
7. Typed GDScript, `class_name` on shared classes, snake_case files,
   PascalCase node names, past-tense signal names for facts
   (`lap_completed`), no debug prints left behind.
8. **Cross-script type references use `const XScript = preload(...)`**
   (not bare class_name types) in annotations, so fresh worktrees pass
   `godot --headless --path . --quit` before any import builds the class
   cache. Keep the `class_name` declarations themselves.

## Workflow

- Work in ROADMAP.md slices, in order. A slice is done when the game runs and
  the acceptance line is observed working (run it, screenshot it or read the
  output). Tick the checkbox; don't start the next slice mid-slice.
- Car feel is sacred: any change touching car handling gets play-verified via
  godot-mcp before it's called done.
- Commits: one coherent change each, imperative mood ("Add ghost replay").
