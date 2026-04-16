# Overlap — Agent Guide

`AGENTS.md` is the canonical instruction file for agents working in this repo. Keep `CLAUDE.md` as a thin compatibility pointer only. If the two ever diverge, follow and update `AGENTS.md`.

## Quick Context

Godot 4.6 arcade racer prototype. GDScript only. Jolt Physics. MCP Bridge enabled on port 6008.

Read `DESIGN.md` for game vision, design principles, and constraints. That document is the authority on _what_ we're building and _why_. This file covers _how_ to work in the repo.

## Key Files

- `main.gd` — Round flow orchestration, pit stop sequencing, and track placement state.
- `car/car.gd` — Car physics controller. Drift state machine, throttle/brake, steering. All physics in `_integrate_forces`.
- `car/car_stats.gd` — `CarStats` resource class. All tunable vehicle parameters.
- `car/default_stats.tres` — Default car stats instance.
- `car/drift_feedback.gd` — Drift smoke particles. Signal-driven by car drift state, created at runtime.
- `camera/game_camera.gd` — Dynamic follow camera with speed-based zoom.
- `race/coin.gd` — Collectible coin pickup with multiplier-scaled payouts.
- `race/hazard_type.gd` — Hazard registry for scene paths, names, and descriptions.
- `race/hazard_preview_helper.gd` — Shared material and collision toggling for hazard preview vs. placed states.
- `race/hazards/*.gd` — Persistent track hazards. Preview visuals and hazard effects.
- `race/lap_tracker.gd` — Lap progression and anti-cheese lap validation.
- `race/run_state.gd` — Round timer, lap timing, multiplier, and currency rewards.
- `track/test_track.gd` — Tile-layout-driven track generation, surface queries, and placement transforms.
- `track/track_layout.gd` — Authored starter layout resource built from placed track tiles.
- `track/track_tile_definition.gd` — Tile shape resource describing entry/exit sockets and local centerline points.
- `ui/run_hud.gd` — Prototype race HUD for lap/timer/economy state.
- `main.tscn` — Main scene. Car, track, camera, lighting, environment.

## Working Rules

- Use Godot MCP tools for all scene, node, and property operations. Use file writes only for GDScript (.gd) files where exact content control is needed.
- Keep changes scoped. One scene, one system, or one module seam at a time.
- Prefer reading project state (scenes, scripts, editor status) before making changes.
- After MCP-based changes, validate through the editor when practical: check scene tree, run the scene, inspect output.
- Avoid speculative "not yet" state notes that will rot. Document current concrete state or a durable invariant instead.
- When a change alters documented current-state behavior, tables, layers, or workflows, update the relevant docs in the same change.

## Commits

- One logical change per commit. Don't mix unrelated work.
- If a change spans multiple files but serves one purpose (e.g., "add camera system" touches script + scene), that's one commit.
- If a change does two things (e.g., adds a feature AND fixes an unrelated bug), split it into two commits.
- Write commit messages that say what and why, not how. The diff shows how.
- No WIP commits on main.

## Godot Conventions

- Follow the official GDScript style guide: `snake_case` for variables and functions, `PascalCase` for classes and nodes, `CONSTANT_CASE` for constants.
- Use static typing everywhere: `var speed: float = 10.0`, typed arrays, typed return values.
- Use `const` instead of `var` wherever possible.
- Give every non-trivial script a `class_name`.
- Use Godot's Input Map for all player input — no hardcoded key constants.
- Use `@export` with proper types for inspector-visible properties. Prefer specific types (`CarStats`) over generic ones (`Resource`).
- Cache node references with `@onready` — never call `$Node` or `get_node()` inside `_process()` or `_physics_process()`.
- Signals up, calls down. Children emit signals; parents connect to them. Avoid `get_parent()` for cross-node communication.

## Physics

- Physics tick rate is 120Hz (`project.godot`). All force magnitudes in `CarStats` are calibrated to this rate. Do not change without retuning.
- Collision layers are assigned deliberately. Current assignments:

| Layer | Name             | Used by                                                             |
| ----- | ---------------- | ------------------------------------------------------------------- |
| 1     | `car`            | Car `RigidBody3D`                                                   |
| 2     | `track_wall`     | Track wall `StaticBody3D`s and placed wall barriers                 |
| 3     | `track_surface`  | Reserved for future use                                             |
| 4     | `collectible`    | Coins and future pickups                                            |
| 5     | `track_modifier` | Boost pads, oil slicks, slow zones, and future placed track effects |

- The layer names in `project.godot` and this table are the source of truth. When adding a new collidable type, claim the next free layer, update both, and set `collision_mask` to only the layers that object needs.

## Architecture

- **Resources for data**: Car stats, track definitions, and other tunable data live in `Resource` subclasses. Resources are design-time data, not runtime state.
- **Scenes are self-contained**: Each scene should work without knowledge of its parent. Compose entities from focused child nodes rather than monolithic scripts.
- **Physics in `_integrate_forces`**: The car uses `_integrate_forces` for all physics work. Do not fight the physics engine from `_process` or `_physics_process` — work with the state object Godot gives you.
- **No giant autoloads**: Avoid a universal `GameManager` singleton. If global state is needed, keep autoloads small and single-purpose.

## Code Quality

- No debug `print()` in committed code. Use `push_warning()` or a debug flag if runtime logging is genuinely needed.
- No magic numbers in physics or gameplay code. Named constants or `@export` vars with clear names.
- No unused variables, signals, or imports.
- Keep scripts focused. If a script exceeds ~150 lines, consider whether it has multiple responsibilities that should be split.

## Track and Level Design

- Track geometry is procedural from a centerline. The wall and surface generation code is intentionally simple — it will evolve.
- Starter tracks are authored from tile resources and stitched into a centerline at runtime. The wall and surface generation code is intentionally simple — it will evolve.
- The current starter layouts map world position to `SurfaceProfile` resources (`tarmac`, `sand`, `grass`) so floor regions can change car handling without per-triangle floor physics.
- Lap counting currently uses track progress plus a virtual checkpoint halfway around the course rather than hand-placed checkpoint volumes.
- Coins are instantiated under `Track/Coins` at round start and distributed around the active track so map swaps still produce readable pickup lines.
- Track points now come from `TrackLayout` and `TrackTileDefinition` resources rather than living directly in `track/test_track.gd`.
- `TrackTileDefinition.footprint` is enforced by layout validation. Multi-cell tiles claim every occupied grid cell, and `entry_cell` / `exit_cell` select which occupied cells own the path sockets.
- Multi-cell footprints currently rotate in 90-degree steps only. Keep 45-degree rotations on `1x1` tiles, or author a dedicated cardinal-orientation variant for larger pieces.
- Keep using deliberate collision layers as new collidable types are added. Do not reuse layer 1 as the default for unrelated objects.

### Pit Stop Flow

- Between rounds the pit stop runs three phases in order: buy positives (currently boost pads plus timer extensions, with timer-extension cost scaling per purchase), draft 1 of 2 offered hazards, then place the drafted hazard on the track. `main.gd` orchestrates this sequencing alongside track placement state.
- Placed positives and hazards persist on the track for subsequent rounds.

### Hazard types

| Name         | Scene path                              | Effect                                                            | Collision layer          |
| ------------ | --------------------------------------- | ----------------------------------------------------------------- | ------------------------ |
| Oil Slick    | `res://race/hazards/oil_slick.tscn`     | Collapses grip on the car for 1.5s after it passes through.       | 5 (`track_modifier`)     |
| Slow Zone    | `res://race/hazards/slow_zone.tscn`     | Caps the car's speed while it remains inside the volume.          | 5 (`track_modifier`)     |
| Wall Barrier | `res://race/hazards/wall_barrier.tscn`  | Solid blocker — throws the car back on impact.                    | 2 (`track_wall`)         |

### Adding a hazard

1. **Script location.** Add the new hazard script under `race/hazards/` with a matching `.tscn` scene. Non-solid modifiers extend `Area3D`; solid blockers extend `StaticBody3D` (see `oil_slick.gd` / `slow_zone.gd` vs. `wall_barrier.gd`).
2. **Base behavior and signals.** The script must expose `set_preview_mode(bool)`, `set_preview_valid(bool)`, and `set_preview_focused(bool)` so the placement flow can drive the preview. Area-based hazards connect `body_entered` / `body_exited` in `_ready`, bail out when `_preview_mode` is true, and (when applicable) skip effects while `RunState.is_round_active` is false. Track any per-car state by `get_instance_id()` and clear it on exit / preview toggles so restarting a round cannot leave stale penalties.
3. **Register in the hazard registry.** Add a new enum value to `HazardType.Type` in `race/hazard_type.gd`, then add matching entries to `SCENE_PATHS`, `DISPLAY_NAMES`, `DESCRIPTIONS`, and `NODE_NAMES`, and include the enum value in `get_available_types()`.
4. **Preview helper wiring.** In `_configure_materials`, call `HazardPreviewHelper.configure_materials` with the two `MeshInstance3D` children and two `StandardMaterial3D` instances. In `_apply_visual_state`, call `HazardPreviewHelper.apply_visual_state` with the base/accent colors and a `Callable` that derives the accent color from the current base color, then call `apply_collision_state_area` (for `Area3D`) or `apply_collision_state_body` (for `StaticBody3D`) so preview mode disables collision and monitoring.
5. **Collision layer assignment.** Non-solid track modifiers use layer 5 (`track_modifier`). Solid blockers that physically stop the car use layer 2 (`track_wall`). Set `collision_mask` to only the layers the hazard needs to detect (typically layer 1 for the car on area hazards; walls use `collision_mask = 0`). If the hazard claims any new layer, update the collision-layer table above in the same change.

## Testing and Validation

- Run the scene after physics or gameplay changes to verify feel — automated tests check correctness, not game feel.
- When Godot MCP is available, use this validation loop:
  1. `editor.status` to confirm the editor and bridge are connected.
  2. `scene.open` or `scene.get_tree` to inspect the target scene before changing it.
  3. Make the smallest scoped change that solves the task.
  4. `run.play` the target scene, then `run.get_output`, then `run.stop`.
  5. Fix any errors introduced by the change before considering the task complete.
- If the session exposes higher-level wrappers such as `godot_run_scene` or `godot_get_output`, treat them as aliases for the same MCP-backed loop. Do not invent commands that are not available in the session.
- For fresh-clone headless validation outside MCP, run one editor-style bootstrap first (`--headless --editor --path ... --quit`) before plain `--headless` checks so repo-defined `class_name` types are registered.
- Use `res://scripts/validate_track_layouts.gd` when changing tile definitions or authored layouts to catch overlaps, unsupported rotations, and broken socket continuity across every layout resource.
- If MCP or editor-backed validation is unavailable, say so explicitly in the handoff. Do not claim runtime validation you did not perform.
- After every non-trivial code change, run two code-review passes when agent tooling is available: one standard review and one adversarial review focused on finding regressions, edge cases, and weak assumptions.
- Treat review as part of implementation, not a separate optional step. Iterate on the change until both review passes report no unresolved medium-or-higher issues, or explicitly document any remaining disagreement in the handoff with the reason it was left unresolved.

## Documentation and Planning

- Keep early design documentation lightweight and easy to revise.
- Use `docs/explorations/` for unresolved design thinking, tradeoff analysis, and candidate mechanics.
- Exploration notes are working documents that evolve with prototyping. They are not implementation authority.
- Promote ideas into authoritative docs only after they are decided and ready to guide implementation.

## Agent Stability Practices

Rules that reduce rework by making repo conventions explicit and machine-readable.

### Prefer machine-readable contracts

- **Input Map over raw keys.** Use named actions from `project.godot` such as `"throttle"` and `"steer_left"`. Do not use `KEY_*` constants or `is_physical_key_pressed()` for gameplay input.
- **Typed exports over generic ones.** Prefer `@export var stats: CarStats` over broad types like `Resource`.
- **`class_name` on every non-trivial script.** This keeps references typed and editor-validated.
- **Named constants over magic numbers.** If a value matters to tuning or behavior, give it a name.

### Validate the real editor loop

- **Read before write.** Inspect scripts, scenes, and current node paths before editing.
- **One system at a time.** Do not combine car-feel, camera, HUD, and track changes in one speculative pass.
- **Do not claim validation you did not perform.** The editor state and runtime output are the authority for scene-backed behavior.

### Collision layers are a contract

- New collidable types must claim a deliberate layer and update the table above in the same change.
- Walls use `collision_mask = 0` because they only need to be detected, not detect others.

### Scene files are fragile

- Prefer MCP tools over hand-editing `.tscn` files.
- If a `.tscn` must be edited as text, keep edits minimal and surgical. Never reformat or reorder sections.
- After any scene file edit, verify the scene still opens cleanly in the editor when that validation path is available.

## Prototype-First Principle

This project is in early prototype phase. Process exists to prevent wasted work on big changes, not to slow down learning. When the fastest path to understanding is "change a value and feel the result," do that.
