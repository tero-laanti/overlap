# Overlap — Agent Guide

`AGENTS.md` is the canonical instruction file for agents working in this repo.
Keep `CLAUDE.md` as a thin compatibility pointer only. If the two ever diverge,
follow and update `AGENTS.md`.

## Quick Context

Godot 4.6 arcade racer prototype. GDScript only. Jolt Physics. MCP Bridge
enabled on port 6008.

Read `DESIGN.md` for game vision, design principles, and constraints. That
document is the authority on _what_ we're building and _why_. This file covers
_how_ to work in the repo.

Use the matching skill under `.claude/skills/<name>/SKILL.md` when the task
clearly fits it. `AGENTS.md` remains the top-level authority if there is any
conflict.

## Key Files

- `main.gd` — Round flow orchestration, pit stop sequencing, and track placement
  state.
- `car/car.gd` — Abstract `Car` base class. Declares the public vehicle API
  (signals, properties, shared defaults) that hazards, HUD, lap tracker,
  camera, and pit stop consume. Concrete controllers subclass this.
- `car/sphere_car.gd` / `car/sphere_car.tscn` — `SphereCar extends Car`. The
  Kenney sphere-vehicle arcade controller: `RigidBody3D` sphere drives via
  `_physics_process` torque, `Car` follows its world position each tick.
- `car/physics_car.gd` / `car/physics_car.tscn` — `PhysicsCar extends Car`.
  The integrator-based legacy controller: `_integrate_forces` applies per-tick
  forces, explicit heading state, `CarStats` governs every knob, ground grace
  periods, surface-aware modifiers. The global default comes from `main.tscn`'s
  `vehicle_scene` `ExtResource`; a `TrackLayout.preferred_vehicle` override
  swaps in a different controller per layout (the figure-eight uses
  `physics_car.tscn` so the bridge crossing runs on the heavier integrator).
- `car/car_physics_proxy.gd` — Hidden rigidbody proxy shared by both
  controllers. Relays `_integrate_forces` and collision events back to the
  bound `Car` subclass.
- `car/car_body_resolver.gd` — Utility that resolves the owning `Car` from a
  colliding body such as the proxy rigidbody.
- `car/car_stats.gd` — `CarStats` resource class. All tunable vehicle
  parameters.
- `car/default_stats.tres` — Default car stats instance.
- `car/car_visual_pose.gd` — Visual pose and wheel steering. Runtime-bound
  sibling node that smooths body lean and wheel yaw against car state.
- `car/drift_feedback.gd` — Drift smoke particles. Signal-driven by car drift
  state, created at runtime.
- `camera/game_camera.gd` — Dynamic follow camera with speed-based zoom.
- `race/coin.gd` — Collectible coin pickup with multiplier-scaled payouts.
- `race/hazard_type.gd` — Hazard registry for scene paths, names, and
  descriptions.
- `race/positive_type.gd` — Positive-offer registry for costs, categories,
  delivery modes, and placement scene paths.
- `race/hazard_preview_helper.gd` — Shared material and collision toggling for
  hazard preview vs. placed states.
- `race/*.gd` — Persistent positive track pieces such as Boost Pads, Coin Gates,
  Drift Ribbons, and Wash Gates.
- `race/hazards/*.gd` — Persistent track hazards. Preview visuals and hazard
  effects.
- `race/lap_tracker.gd` — Lap progression and anti-cheese lap validation.
- `race/run_state.gd` — Round timer, lap timing, multiplier, and currency
  rewards.
- `track/test_track.gd` — Tile-layout-driven track generation, surface queries,
  and placement transforms.
- `track/track_layout.gd` — Authored starter layout resource built from placed
  track tiles. Exposes an optional `preferred_vehicle: PackedScene` that
  `Main.apply_preferred_vehicle` uses to swap the default `vehicle_scene`
  when the layout wants a specific controller.
- `track/track_tile_definition.gd` — Tile shape resource describing entry/exit
  sockets and local centerline points.
- `track/track_mutator.gd` — Round-end track evolution. Replaces one straight
  tile with a detour module so laps lengthen over the course of a run.
- `ui/run_hud.gd` — Prototype race HUD for lap/timer/economy state.
- `main.tscn` — Main scene. Track, camera, lighting, environment, plus an
  instanced `Car` whose scene is selected by the `vehicle_scene`
  `ExtResource` (defaults to `sphere_car.tscn`; swap to `physics_car.tscn`
  to test the legacy controller). An active `TrackLayout.preferred_vehicle`
  override replaces this default at round start via
  `Main.apply_preferred_vehicle` — re-read that method when touching spawn
  sequencing.

## Working Rules

- Use Godot MCP tools for all scene, node, and property operations. Use file
  writes only for GDScript (.gd) files where exact content control is needed.
- Keep changes scoped. One scene, one system, or one module seam at a time.
- Prefer reading project state (scenes, scripts, editor status) before making
  changes.
- After MCP-based changes, validate through the editor when practical: check
  scene tree, run the scene, inspect output.
- Avoid speculative "not yet" state notes that will rot. Document current
  concrete state or a durable invariant instead.
- When a change alters documented current-state behavior, tables, layers, or
  workflows, update the relevant docs in the same change.

## Commits

- One logical change per commit. Don't mix unrelated work.
- If a change spans multiple files but serves one purpose (e.g., "add camera
  system" touches script + scene), that's one commit.
- If a change does two things (e.g., adds a feature AND fixes an unrelated bug),
  split it into two commits.
- Write commit messages that say what and why, not how. The diff shows how.
- No "review changes" commit messages. That has 0 information.
- No WIP commits on main.

## Godot Conventions

- Follow the official GDScript style guide: `snake_case` for variables and
  functions, `PascalCase` for classes and nodes, `CONSTANT_CASE` for constants.
- Use static typing everywhere: `var speed: float = 10.0`, typed arrays, typed
  return values.
- Use `const` instead of `var` wherever possible.
- Give every non-trivial script a `class_name`.
- Use Godot's Input Map for all player input — no hardcoded key constants.
- Use `@export` with proper types for inspector-visible properties. Prefer
  specific types (`CarStats`) over generic ones (`Resource`).
- Cache node references with `@onready` — never call `$Node` or `get_node()`
  inside `_process()` or `_physics_process()`.
- Signals up, calls down. Children emit signals; parents connect to them. Avoid
  `get_parent()` for cross-node communication.

## Physics

- Physics tick rate is 120Hz (`project.godot`). All force magnitudes in
  `CarStats` are calibrated to this rate. Do not change without retuning.
- Collision layers are assigned deliberately. Current assignments:

| Layer | Name             | Used by                                                             |
| ----- | ---------------- | ------------------------------------------------------------------- |
| 1     | `car`            | Car physics proxy `RigidBody3D`                                     |
| 2     | `track_wall`     | Track wall `StaticBody3D`s and placed wall barriers                 |
| 3     | `track_surface`  | Ground collider under every track plus jump ramps                   |
| 4     | `collectible`    | Coins and future pickups                                            |
| 5     | `track_modifier` | Boost pads, oil slicks, slow zones, and future placed track effects |

- The layer names in `project.godot` and this table are the source of truth.
  When adding a new collidable type, claim the next free layer, update both, and
  set `collision_mask` to only the layers that object needs.

### Physics interpolation

`common/physics_interpolation=true` is set in `project.godot`. Without it, the
visual position snaps to the latest physics tick each render frame, which beats
against variable display refresh (notably ProMotion) and produces small
forward-jitter blips during steady-state motion.

Rules to keep it well-behaved:

- **Move transforms from `_physics_process` / `_integrate_forces`, not
  `_process`.** Setting an interpolated node's transform outside the physics
  tick desynchronizes the previous/current pair and causes jitter. Godot will
  warn in the editor when it detects this. Indirect movers (Tween,
  AnimationPlayer driving a transform, NavigationAgent3D) must also be set to
  run on the physics tick — including when they move a parent of an
  interpolated node.
- **Reset interpolation after teleports.** Any non-continuous transform change
  (respawn, snap to a checkpoint, scene re-entry) must be followed by
  `reset_physics_interpolation()` on the moved node. Otherwise the visual
  streaks from old to new across one tick. See `Car.reset_to_transform()` for
  the pattern. The call propagates to children, so calling it on a parent (e.g.
  `Car`) covers the proxy and visual root in one go. Order matters: set the
  new transform, then call `reset_physics_interpolation()`, then (only if you
  also want a tick of motion baked in immediately) set the second transform.
- **Self-smoothing follow nodes opt OUT.** Nodes that compute their own
  `_process`-rate smoothing (e.g. `GameCamera`) must set
  `physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF` in
  `_ready`. Otherwise you get double-interpolation and the
  "interpolated node modified outside physics process" warning. Same applies to
  any future HUD-attached or look-at helper that updates from `_process`.
- **Reading transforms from `_process` returns the interpolated value.** That
  is what we want for visuals (camera, particle parents, HUD anchors). Do not
  use those reads for gameplay decisions — gameplay logic stays in
  `_integrate_forces` where `state.transform` is the raw tick state.
- **Physics queries are unaffected.** `Area3D` overlaps, raycasts, and
  collision callbacks fire on the physics tick from raw transforms — coin
  pickups, hazard triggers, and ground probes need no change.
- **`local_coords = false` particles** track the visually-interpolated parent
  transform smoothly. Drift smoke and any future world-space particle setups do
  not need extra handling.
- **Debug tip.** When investigating suspected interpolation bugs (missing
  `reset_physics_interpolation()` calls, late `_process` writes, and so on),
  temporarily drop `common/physics_ticks_per_second` to `10` in
  `project.godot`. Streaks and pops become obvious; restore to `120` once
  fixed.
- **3D collision-shape debug draw is not interpolated.** When `Debug > Visible
  Collision Shapes` is on, expect the wireframes to lag slightly behind the
  visual mesh — that is a known engine quirk, not a bug in our code.

### Direction conventions

Godot baseline on every `Node3D`:

- `-basis.z` → **forward**
- `+basis.x` → **right**
- `+basis.y` → **up**

Car heading — invariants shared by every concrete controller:

- `-car.global_basis.z` is the yaw-only flat-heading forward vector, in world
  space, safe to read from outside the car. Each controller guarantees this on
  every physics tick by a different mechanism (see below).
- Visual lean (pitch/roll) never lives on `car.global_basis`. PhysicsCar
  writes lean onto `VisualRoot` via `CarVisualPose`; SphereCar applies
  ground-align tilt directly to `VisualRoot.global_transform`. Either way,
  `car.global_basis` is a flat heading frame that does not wobble with
  terrain.

**PhysicsCar** (integrator model):

- `_heading_forward` (`PhysicsCar` private state) is the gameplay truth.
  Yaw-only `Vector3` flattened onto world UP.
- `-car.global_basis.z` is the same value, re-synced each tick by
  `_sync_root_from_proxy_origin()`.
- Inside `_integrate_proxy_forces`, prefer the named accessors
  (`get_drive_forward_vector(up)`, `get_heading_forward()`,
  `get_support_up_axis()`, `basis_from_forward_and_up(fwd, up)`) over
  hand-rolled `basis` math. They encode the "forward is `-z`, projected onto
  the support plane" convention in one place.

**SphereCar** (Kenney arcade model):

- The Car root basis IS the heading. There is no `_heading_forward` field;
  yaw is accumulated directly on `global_basis` via `rotate_y()` in
  `_physics_process`.
- `-car.global_basis.z` is authoritative immediately after the yaw rotate.
  `get_heading_forward()` falls through to the base-class default, which
  returns the projected `-global_basis.z`.

Sign conventions shared by both controllers (values exposed on `Car`):

| Value                  | +                       | -                          | Source                                         |
| ---------------------- | ----------------------- | -------------------------- | ---------------------------------------------- |
| `throttle_input`       | throttle                | brake / reverse            | `Input.get_axis("brake", "throttle")`          |
| `steering_input`       | steer left              | steer right                | `Input.get_axis("steer_right", "steer_left")`  |

PhysicsCar-only (referenced inside `_integrate_proxy_forces`):

| Value                  | +                       | -                          | Source                                         |
| ---------------------- | ----------------------- | -------------------------- | ---------------------------------------------- |
| `forward_speed`        | moving along heading    | moving opposite heading    | `planar_velocity.dot(forward)`                 |
| `lateral_speed`        | sliding right           | sliding left               | `planar_velocity.dot(right)`                   |
| `alignment`            | heading ≈ motion (fwd)  | motion opposes heading     | `_heading_forward.dot(motion_forward)`         |

`alignment` is a dot of two unit vectors, so `+1` is pure forward, `0` is
perpendicular, `-1` is pure reverse. `HEADING_REVERSE_ALIGN_DOT_THRESHOLD =
-0.2` is the "clearly reversing" band used to gate PhysicsCar's reverse-
heading recovery. SphereCar has no equivalent — it does not reconcile
heading against velocity.

The `steering_input` sign is counter-intuitive because `Input.get_axis(neg,
pos)` returns `strength(pos) - strength(neg)`, and the call passes
`steer_right` as `neg` and `steer_left` as `pos`. So pressing A
(`steer_left`) produces `+1`, which in PhysicsCar flows through
`_get_target_yaw_speed` into a positive yaw rotation around world UP —
i.e., the car turns **left** (right-handed rotation sense). SphereCar uses
the same public `steering_input` field for the legacy sign but drives yaw
from an internal `_input.x = Input.get_axis("steer_left", "steer_right")`
with the opposite sign, baked into `rotate_y(-_input.x * ...)`. The visual
pose negates before applying roll so the body leans out of the turn
correctly. Do not flip the axis wiring without re-checking every downstream
use.

## Architecture

- **Resources for data**: Car stats, track definitions, and other tunable data
  live in `Resource` subclasses. Resources are design-time data, not runtime
  state.
- **Scenes are self-contained**: Each scene should work without knowledge of its
  parent. Compose entities from focused child nodes rather than monolithic
  scripts.
- **Physics in `_integrate_forces`**: The hidden car proxy uses
  `_integrate_forces` for all physics work, relayed through `Car`. Do not fight
  the physics engine from `_process` or `_physics_process` — work with the
  state object Godot gives you.
- **No giant autoloads**: Avoid a universal `GameManager` singleton. If global
  state is needed, keep autoloads small and single-purpose.

## Code Quality

- No debug `print()` in committed code. Use `push_warning()` or a debug flag if
  runtime logging is genuinely needed.
- No magic numbers in physics or gameplay code. Named constants or `@export`
  vars with clear names.
- No unused variables, signals, or imports.
- Keep scripts focused. If a script exceeds ~150 lines, consider whether it has
  multiple responsibilities that should be split.

## Track and Level Design

- Track geometry is procedural from a centerline. The wall and surface
  generation code is intentionally simple — it will evolve.
- Starter tracks are authored from tile resources and stitched into a centerline
  at runtime. The wall and surface generation code is intentionally simple — it
  will evolve.
- Starter layouts map world position to `SurfaceProfile` resources (`tarmac`,
  `sand`, `grass`) so floor regions can change car handling without per-triangle
  floor physics.
- Lap counting uses track progress plus a virtual checkpoint halfway around the
  course rather than hand-placed checkpoint volumes.
- Coins are instantiated under `Track/Coins` at round start and distributed
  around the active track so map swaps still produce readable pickup lines.
- Track points come from `TrackLayout` and `TrackTileDefinition` resources.
- `TrackTileDefinition.footprint` is enforced by layout validation. Multi-cell
  tiles claim every occupied grid cell, and `entry_cell` / `exit_cell` select
  which occupied cells own the path sockets.
- Multi-cell footprints rotate in 90-degree steps only. Keep 45-degree rotations
  on `1x1` tiles, or author a dedicated cardinal-orientation variant for larger
  pieces.
- Keep using deliberate collision layers as new collidable types are added. Do
  not reuse layer 1 as the default for unrelated objects.

### Procedural self-crossing layouts

- `TrackLayout.procedural_shape` swaps the tile pipeline for a procedurally
  generated centerline. Today the only supported value is
  `&"figure_eight"`, which produces a lemniscate with one of the two
  crossings elevated into a bridge. `procedural_half_size`,
  `procedural_segment_count`, `procedural_bridge_height`, and
  `procedural_bridge_fraction` tune the shape and the ramp profile.
- `TrackLayout.has_self_crossing()` is the runtime signal consumed by
  `TestTrack`: it switches ground rendering to a single grass slab under the
  bounds (the tile infield triangulator cannot handle a self-intersecting
  polygon), emits a tarmac/sand trimesh collider so the bridge is physically
  drivable, and flips the drivable strip's `cull_mode` to
  `CULL_DISABLED` so the bridge underside stays visible.
- `TestTrack._get_closest_segment()` uses 3D distance to pick the active
  segment and 2D distance to return surface-type thresholds. That keeps
  `get_progress_at_position()` and `get_surface_profile_at_position()`
  disambiguating at the crossing — a car on the bridge reads bridge
  progress, a car underneath reads the ground pass.
- `TrackMutator` skips procedural layouts; keep `track_mutation_enabled =
  false` on the `Main` node while those layouts are active.

### Track evolution

- `TrackMutator` (`track/track_mutator.gd`) splices a detour tile into the
  active `TrackLayout` on round end via `main.gd._mutate_track_if_needed()`,
  starting at `track_mutation_start_round` (default 2). Round 1 always runs the
  authored layout.
- The mutator builds a fresh `TrackLayout` each time instead of mutating the
  loaded `.tres` in place; the source resource stays clean.
  `TestTrack.set_active_layout()` swaps the live layout and synchronously
  rebuilds centerline, meshes, and length cache so downstream consumers (coin
  rebuild, hazard placement, car respawn) read the new geometry.
- Detour modules live in `track/tiles/detour_*.tres`. Each must share the base
  entry/exit directions of the straights it replaces and carry one or more extra
  rows orthogonal to travel (`footprint.y` ≥ 2) so the detour geometry sits in
  previously empty grid cells. Shallow 1x2 / 2x2 `bump` tiles add one orthogonal
  row; deeper 1x3 / 2x3 `hairpin` tiles add two rows for a tighter apex;
  `chicane` tiles put entry/exit in the middle row and peak into the rows on
  either side for an S-curve. A detour is dropped in only when every extra cell
  it occupies is clear in the layout.
- Candidate straights are filtered out when any placed positive, hazard, or the
  car spawn position falls inside their footprint — a mutation never orphans a
  placed item.
- When a splice lands, `TrackMutator` exposes `last_mutation_changed`,
  `last_mutation_world_center`, and `last_mutation_display_name` so callers can
  telegraph the change. `main.gd` focuses the camera on the new section and
  shows a full-screen "Track Evolved" preview overlay; the pit-stop screen only
  appears after the player presses `continue_round` / `place_boost_pad`.
- Set `debug_round_telemetry` on the `Main` node to have per-round lap times
  printed to stdout — useful for sanity-checking that new detour shapes are
  actually slowing laps down across a run.
- Run
  `godot --headless --path . --script res://scripts/validate_track_mutator.gd`
  when touching `track_mutator.gd`, a detour tile, or the layout data model. It
  iterates six mutations per starter layout and fails if the produced layout
  ever breaks validation.

### Pit Stop Flow

- Between rounds the pit stop runs three phases in order: buy 3 positive offers
  (always 1 utility, 1 greed, 1 handling/line-edit), draft 1 of 2 offered
  hazards (always 1 line-tax and 1 hard-reroute), then place queued positives
  and the drafted hazard on the track. `main.gd` orchestrates this sequencing
  alongside track placement state.
- `Time Bank` is the anchor utility positive: each purchase permanently adds
  `+5s` to the run's base starting round timer and raises the next Time Bank
  cost for the same run.
- Placed positives and hazards persist on the track for subsequent rounds.

### Positive types

| Name         | Scene path                     | Effect                                                                    | Collision layer      |
| ------------ | ------------------------------ | ------------------------------------------------------------------------- | -------------------- |
| Time Bank    | N/A (`instant`)                | Permanently adds `+5s` to the run timer.                                  | None                 |
| Boost Pad    | `res://race/boost_pad.tscn`    | Adds a reusable forward speed burst to a chosen line.                     | 5 (`track_modifier`) |
| Coin Gate    | `res://race/coin_gate.tscn`    | Rewards a centered pass once per lap with a multiplier-scaled cash burst. | 5 (`track_modifier`) |
| Drift Ribbon | `res://race/drift_ribbon.tscn` | Rewards the first in-zone drift each lap with extra carry and grip.       | 5 (`track_modifier`) |
| Wash Gate    | `res://race/wash_gate.tscn`    | Clears temporary grip and speed penalties on pass-through.                | 5 (`track_modifier`) |

### Hazard types

| Name          | Scene path                              | Effect                                                      | Collision layer      |
| ------------- | --------------------------------------- | ----------------------------------------------------------- | -------------------- |
| Oil Slick     | `res://race/hazards/oil_slick.tscn`     | Collapses grip on the car for 1.5s after it passes through. | 5 (`track_modifier`) |
| Slow Zone     | `res://race/hazards/slow_zone.tscn`     | Caps the car's speed while it remains inside the volume.    | 5 (`track_modifier`) |
| Gravel Spill  | `res://race/hazards/gravel_spill.tscn`  | Bleeds traction and speed while the car sits in the patch.  | 5 (`track_modifier`) |
| Crosswind Fan | `res://race/hazards/crosswind_fan.tscn` | Pushes the car laterally off the ideal line.                | 5 (`track_modifier`) |
| Wall Barrier  | `res://race/hazards/wall_barrier.tscn`  | Solid blocker — throws the car back on impact.              | 2 (`track_wall`)     |
| Cone Chicane  | `res://race/hazards/cone_chicane.tscn`  | Staggered blockers that force a slalom through the segment. | 2 (`track_wall`)     |
| Shutter Gate  | `res://race/hazards/shutter_gate.tscn`  | Wall that rises and falls on a cycle. Read the rhythm or wait. | 2 (`track_wall`)  |

### Adding a hazard

1. **Script location.** Add the new hazard script under `race/hazards/` with a
   matching `.tscn` scene. Non-solid modifiers extend `Area3D`; solid blockers
   extend `StaticBody3D` (see `oil_slick.gd` / `slow_zone.gd` vs.
   `wall_barrier.gd`).
2. **Base behavior and signals.** The script must expose
   `set_preview_mode(bool)`, `set_preview_valid(bool)`, and
   `set_preview_focused(bool)` so the placement flow can drive the preview.
   Area-based hazards connect `body_entered` / `body_exited` in `_ready`, bail
   out when `_preview_mode` is true, and (when applicable) skip effects while
   `RunState.is_round_active` is false. Track any per-car state by
   `get_instance_id()` and clear it on exit / preview toggles so restarting a
   round cannot leave stale penalties.
3. **Register in the hazard registry.** Add a new enum value to
   `HazardType.Type` in `race/hazard_type.gd`, then add matching entries to
   `SCENE_PATHS`, `DISPLAY_NAMES`, `DESCRIPTIONS`, `NODE_NAMES`, `CATEGORIES`,
   and `DRAFT_WEIGHTS`, and include the enum value in `get_available_types()`.
4. **Preview helper wiring.** In `_configure_materials`, call
   `HazardPreviewHelper.configure_materials` with the two `MeshInstance3D`
   children and two `StandardMaterial3D` instances. In `_apply_visual_state`,
   call `HazardPreviewHelper.apply_visual_state` with the base/accent colors and
   a `Callable` that derives the accent color from the current base color, then
   call `apply_collision_state_area` (for `Area3D`) or
   `apply_collision_state_body` (for `StaticBody3D`) so preview mode disables
   collision and monitoring.
5. **Collision layer assignment.** Non-solid track modifiers use layer 5
   (`track_modifier`). Solid blockers that physically stop the car use layer 2
   (`track_wall`). Set `collision_mask` to only the layers the hazard needs to
   detect (typically layer 1 for the car on area hazards; walls use
   `collision_mask = 0`). If the hazard claims any new layer, update the
   collision-layer table above in the same change.

## Testing and Validation

- Run the scene after physics or gameplay changes to verify feel — automated
  tests check correctness, not game feel.
- When Godot MCP is available, use this validation loop:
  1. `editor.status` to confirm the editor and bridge are connected.
  2. `scene.open` or `scene.get_tree` to inspect the target scene before
	 changing it.
  3. Make the smallest scoped change that solves the task.
  4. `run.play` the target scene, then `run.get_output`, then `run.stop`.
  5. Fix any errors introduced by the change before considering the task
	 complete.
- If the session exposes higher-level wrappers such as `godot_run_scene` or
  `godot_get_output`, treat them as aliases for the same MCP-backed loop. Do not
  invent commands that are not available in the session.
- For fresh-clone headless validation outside MCP, run one editor-style
  bootstrap first (`--headless --editor --path ... --quit`) before plain
  `--headless` checks so repo-defined `class_name` types are registered.
- Use `res://scripts/validate_track_layouts.gd` when changing tile definitions
  or authored layouts to catch overlaps, unsupported rotations, and broken
  socket continuity across every layout resource.
- If MCP or editor-backed validation is unavailable, say so explicitly in the
  handoff. Do not claim runtime validation you did not perform.
- After every non-trivial code change, run two code-review passes when agent
  tooling is available: one standard review and one adversarial review focused
  on finding regressions, edge cases, and weak assumptions.
- Treat review as part of implementation, not a separate optional step. Iterate
  on the change until both review passes report no unresolved medium-or-higher
  issues, or explicitly document any remaining disagreement in the handoff with
  the reason it was left unresolved.

## Change Playbook

A pragmatic checklist distilled from recurring lessons. Walk it top-to-bottom
before marking a non-trivial change done. When in doubt, prefer understanding
the root cause over a surface patch.

### Before writing code

- Read the target file end-to-end. Read one sibling that exercises the same
  pattern (e.g., `car/drift_feedback.gd` and `car/car_audio.gd` are the
  reference shape for runtime-bound sibling nodes that attach to `Car`).
- If fixing a bug, reproduce it in `scripts/validate_*.gd` first and confirm
  the test fails against the unfixed code. A green fix without a previously
  red test is a guess, not a fix.
- Enumerate the reset/teardown paths any new state has to survive. For car
  state that means `reset_to_transform`, `set_frozen(true)`,
  `set_controls_enabled(false)`, and `_exit_tree` on whichever node owns it.
  Missing even one of these is how stale state turns into next-round bugs.
- Decide the scope and stick to it. One system per commit. Do not mix a
  feel tweak with a refactor — the review signal gets muddy and the diff
  becomes hard to revert.

### While writing code

- Type everything. `var`, parameter, return, collection — `Array[int]`,
  `Dictionary[int, Car]`. Variants and untyped dictionaries are a red flag.
- Name every threshold, duration, rate, and tuning value as a
  `CONSTANT_CASE` at the top of the file, with a one-line comment if the
  value is non-obvious. Literals inside branch expressions age badly.
- Prefer `@export var foo: T = default` on `Resource` subclasses; avoid
  the backing-variable + getter/setter form. See "Web Builds" for the
  import-cache failure mode this pattern causes.
- Signals down the tree, direct calls up. Never `get_parent()` for cross-
  node communication. A sibling pattern (like `CarVisualPose` ←→ `Car`)
  is a `bind_car(self)` handshake plus public getters on the parent, not
  private-underscore access from outside.
- When a helper is about to be called from another script, drop its `_`
  prefix and treat it as public API. Don't grant cross-script access to
  `_foo` state without a getter — it silently broadens the contract and
  no future refactor will know who depends on it.
- Avoid the "precompute once per frame into a cached flag" habit unless
  profiling says to. A clear call site beats a clever optimization, and
  an idle early-out (see `CarVisualPose._update_visual_pose`) should
  require strict equality with the smoothed target, not a loose threshold
  that could freeze mid-animation.

### Adding a new Area3D-based hazard or modifier

Required before any PR:

- Scaffold against `race/hazards/slow_zone.gd` or `race/hazards/gravel_spill.gd`.
  They are the canonical pattern — duplicating their shape avoids
  re-discovering every pitfall.
- Key per-body state by `body.get_instance_id()` (not `car.get_instance_id()`).
  Commit a8571df moved every hazard to this pattern; exit cleanup breaks if
  you regress it because the proxy's `car_owner` may already be null by the
  time `body_exited` fires.
- `_on_body_entered` must skip on `_preview_mode`, on
  `_run_state and not _run_state.is_round_active`, and on `car == null`.
- `_on_body_exited` must erase from `_active_cars` / `_triggered_body_ids`
  even when `is_instance_valid(stored_car)` is false. Stale entries are
  how modifiers leak across rounds.
- Register the hazard in `race/hazard_type.gd` (enum, scene path, display
  name, description, node name, category, draft weight) in the same
  commit that adds the script. Missing registry entries break the draft
  phase silently.
- Claim the right collision layer per the table in "Physics". If the
  hazard is solid, layer 2 (`track_wall`); if a passing modifier, layer 5
  (`track_modifier`).

### Validator patterns

- Two per-controller validators live under `scripts/`:
  - `validate_physics_car.gd` — exercises `PhysicsCar` (integrator-based).
	Swaps `main.tscn`'s default Car child for a `physics_car.tscn` instance
	before adding Main to the tree.
  - `validate_sphere_car.gd` — smoke test for `SphereCar` (Kenney sphere
	arcade). Intentionally narrow: boots, responds to throttle, travels far.
- New bug → new test. Add it to the validator that matches the affected
  controller (or both, if the bug is base-class). Reach into underscored
  state only inside validator scripts.
- Tests may reach into underscored state (`car._visual_pose._visual_pitch_angle`,
  `slow_zone._active_cars`) — that is acceptable inside a validator script
  because it lets the test check the actual invariant without expanding
  the public API surface. Do NOT mirror that access from gameplay code.
- Print one status line per test on success, even for passing cases —
  the CI log is often the only artifact a future agent has.
- When asserting a post-transient state (e.g., pitch returns to neutral
  after landing), also assert that the transient actually happened
  (non-zero peak) so the test cannot be passed by a guard that silently
  freezes the state it was meant to check.

### Before committing

1. `bash scripts/headless_check.sh` — boots the project headless and runs
   both per-controller validators (`validate_sphere_car.gd`,
   `validate_physics_car.gd`). Exit 0 is mandatory; inspect the metrics line
   for each test, not just the exit code.
2. For a narrower targeted run:
   `godot --headless --path . --script res://scripts/validate_physics_car.gd`
   or `validate_sphere_car.gd` — pick whichever controller your change
   touches. Required after any car, hazard, or track-surface change.
3. If the change alters `track_mutator.gd`, a detour tile, or the layout
   data model, also run
   `godot --headless --path . --script res://scripts/validate_track_mutator.gd`.
4. Run the scene and exercise the feature if it's a feel change. Automated
   tests catch correctness, not feel.
5. Run a standard and an adversarial review agent on the diff. Resolve
   every Medium-or-higher finding or document the explicit disagreement
   in the commit message.
6. If any `Resource` script was refactored, clear the import cache
   (`rm -rf .godot`) before any web-build pipeline runs. See "Web Builds".
7. Update this file, `CLAUDE.md`, `DESIGN.md`, or any table in the same
   commit when they no longer match the code. Drift between doc and code
   is how agents end up patching the wrong invariant.

## Documentation and Planning

- Keep early design documentation lightweight and easy to revise.
- Use `docs/explorations/` for unresolved design thinking, tradeoff analysis,
  and candidate mechanics.
- Exploration notes are working documents that evolve with prototyping. They are
  not implementation authority.
- Promote ideas into authoritative docs only after they are decided and ready to
  guide implementation.

## Agent Stability Practices

Rules that reduce rework by making repo conventions explicit and
machine-readable.

### Prefer machine-readable contracts

- **Input Map over raw keys.** Use named actions from `project.godot` such as
  `"throttle"` and `"steer_left"`. Do not use `KEY_*` constants or
  `is_physical_key_pressed()` for gameplay input.
- **Typed exports over generic ones.** Prefer `@export var stats: CarStats` over
  broad types like `Resource`.
- **`class_name` on every non-trivial script.** This keeps references typed and
  editor-validated.
- **Named constants over magic numbers.** If a value matters to tuning or
  behavior, give it a name.

### Validate the real editor loop

- **Read before write.** Inspect scripts, scenes, and current node paths before
  editing.
- **One system at a time.** Do not combine car-feel, camera, HUD, and track
  changes in one speculative pass.
- **Do not claim validation you did not perform.** The editor state and runtime
  output are the authority for scene-backed behavior.

### Collision layers are a contract

- New collidable types must claim a deliberate layer and update the table above
  in the same change.
- Walls use `collision_mask = 0` because they only need to be detected, not
  detect others.

### Scene files are fragile

- Prefer MCP tools over hand-editing `.tscn` files.
- If a `.tscn` must be edited as text, keep edits minimal and surgical. Never
  reformat or reorder sections.
- After any scene file edit, verify the scene still opens cleanly in the editor
  when that validation path is available.

## Web Builds

The game ships to itch.io via `.github/workflows/deploy.yml`. Four channels are
pushed per run: `html`, `windows`, `linux`, `macos`. Local editor behavior and
the exported web build do not always agree — the rules below keep the web target
from silently diverging.

### Resource scripts — pitfalls that only surface on web

1. **Prefer plain `@export var foo: T = default` on `Resource` subclasses.**
   Avoid the private-backing-variable + getter/setter pattern (`var _foo: T`
   with `@export var foo: T: get: ...; set(value): ...`). It serializes fine on
   desktop, but after a script refactor the stale import cache can drop the
   stored overrides on web, leaving properties at their script defaults.
2. **Avoid `@export_enum("A:0", "B:1", ...) var x: int`.** Use plain
   `@export var x: int = 0` and document the encoding in a comment. The
   `@export_enum` form is also cache-sensitive when the script's structure
   changes.
3. **Reserve setter-based `@export` for cases that actually need side effects.**
   Observer refresh (`emit_changed` / connecting to child `changed` signals)
   only drives editor live-preview. Runtime code doesn't need it; removing it
   costs nothing at runtime.

### After any significant `Resource` script refactor

Always clear the import cache before shipping a web build:

```
rm -rf .godot
# reopen Godot; let it reimport everything
```

Symptoms that point to a stale cache: desktop builds behave correctly, but web
shows properties loading as script defaults instead of the values in `.tres`
files. Cache clear first, diagnose second.

### Impact of the plain-`@export` preference

- **Inspector UX.** No enum dropdown for direction fields; authors type raw
  numbers. Doesn't matter for AI-driven edits that read code, matters slightly
  for human authoring.
- **Editor live refresh.** Parent resources no longer auto-repaint when a nested
  resource's internal property changes in the inspector. Close/reopen the scene
  or reselect the affected resource to force a refresh. Only affects editor
  authoring flow; no runtime consequence.
- **Runtime.** Zero. Loaded properties, rotation math, track generation all
  behave identically.

### Renderer parity

`project.godot` uses the `mobile` rendering method so the local editor preview
and the WebGL 2 / Compatibility fallback used by the web build share a shading
path. Do not switch to `forward_plus` without also planning for the web
divergence this will re-introduce.

## Prototype-First Principle

This project is in early prototype phase. Process exists to prevent wasted work
on big changes, not to slow down learning. When the fastest path to
understanding is "change a value and feel the result," do that.
