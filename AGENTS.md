# Overlap — Agent Guide

`AGENTS.md` is the canonical instruction file for agents working in this repo. Keep `CLAUDE.md` as a thin compatibility pointer only. If the two ever diverge, follow and update `AGENTS.md`.

## Quick Context

Godot 4.6 arcade racer prototype. GDScript only. Jolt Physics. MCP Bridge enabled on port 6008.

Read `DESIGN.md` for game vision, design principles, and constraints. That document is the authority on *what* we're building and *why*. This file covers *how* to work in the repo.

## Key Files

- `car/car.gd` — Car physics controller. Drift state machine, throttle/brake, steering. All physics in `_integrate_forces`.
- `car/car_stats.gd` — `CarStats` resource class. All tunable vehicle parameters.
- `car/default_stats.tres` — Default car stats instance.
- `camera/game_camera.gd` — Dynamic follow camera with speed-based zoom.
- `track/test_track.gd` — Procedural track generation from a hand-authored centerline.
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
- Give every non-trivial script a `class_name`.
- Use Godot's Input Map for all player input — no hardcoded key constants.
- Use `@export` with proper types for inspector-visible properties. Prefer specific types (`CarStats`) over generic ones (`Resource`).
- Cache node references with `@onready` — never call `$Node` or `get_node()` inside `_process()` or `_physics_process()`.
- Signals up, calls down. Children emit signals; parents connect to them. Avoid `get_parent()` for cross-node communication.

## Physics

- Physics tick rate is 120Hz (`project.godot`). All force magnitudes in `CarStats` are calibrated to this rate. Do not change without retuning.
- Collision layers are assigned deliberately. Current assignments:

| Layer | Name | Used by |
|-------|------|---------|
| 1 | `car` | Car `RigidBody3D` |
| 2 | `track_wall` | Track wall `StaticBody3D`s |
| 3 | `track_surface` | Reserved for future use |

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
- Track points currently live in the script. If multiple authored layouts or track-editing workflows appear, move them into a dedicated `Resource`.
- Keep using deliberate collision layers as new collidable types are added. Do not reuse layer 1 as the default for unrelated objects.

## Testing and Validation

- Run the scene after physics or gameplay changes to verify feel — automated tests check correctness, not game feel.
- When Godot MCP is available, use this validation loop:
  1. `editor.status` to confirm the editor and bridge are connected.
  2. `scene.open` or `scene.get_tree` to inspect the target scene before changing it.
  3. Make the smallest scoped change that solves the task.
  4. `run.play` the target scene, then `run.get_output`, then `run.stop`.
  5. Fix any errors introduced by the change before considering the task complete.
- If the session exposes higher-level wrappers such as `godot_run_scene` or `godot_get_output`, treat them as aliases for the same MCP-backed loop. Do not invent commands that are not available in the session.
- If MCP or editor-backed validation is unavailable, say so explicitly in the handoff. Do not claim runtime validation you did not perform.

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
