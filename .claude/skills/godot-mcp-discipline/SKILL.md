---
name: godot-mcp-discipline
description: Use when touching scenes, nodes, properties, or project state in a Godot 4.6 repo with the godot MCP bridge available. Codifies when to use mcp__godot__* tools vs direct file writes, the read-before-write loop, the run-and-observe validation cycle, and scene-file fragility rules.
---

# Godot MCP Discipline

## Core Principle

**Scenes, nodes, and project state: drive through the MCP. GDScript source: edit as text.**

Godot's `.tscn` / `.tres` files are fragile. They serialize node ids, subresource numbering, and inspector state in ways that a text edit can silently corrupt. The MCP bridge talks to the live editor, so every operation round-trips through the same code that saves a scene when you press Ctrl+S.

GDScript source (`.gd`) is plain text, never corrupted by an edit, and faster to touch via the file-write tools.

---

## When to Use

Activate this skill when:
- Modifying any `.tscn` or `.tres` file
- Adding, removing, reparenting, or renaming nodes
- Setting inspector properties (including `@export` values on a node instance)
- Creating new scenes
- Running the project or a specific scene for validation
- Inspecting current project state (scene tree, open scripts, editor status)
- Getting profiler data or screenshots from a running game

## When NOT to Use

- Editing GDScript source (`.gd`) — use Read / Write / Edit
- Editing documentation, shell scripts, CI configuration — use Read / Write / Edit
- Reading a file whose exact textual content matters (e.g. diffing a `.tscn` during debugging) — use Read

---

## The Read-Before-Write Loop

**Never modify state you haven't just inspected.** The editor is a shared mutable system; its state drifts while you're off-thread. Every change to scene-backed behavior follows the loop in `AGENTS.md` → "Testing and Validation" (`editor.status` → `scene.open`/`scene.get_tree` → change → `run.play` → `run.get_output` → `run.stop`). This skill adds the MCP tool bindings for that loop:

| Loop step | MCP tool |
|---|---|
| Editor + bridge up? | `godot_editor_status` |
| Inspect target scene | `godot_get_scene_tree` (open) or `godot_parse_scene` (without opening) |
| Run | `godot_run_scene` |
| Read output | `godot_get_output` |
| Stop | `godot_stop_scene` |

If `godot_editor_status` fails, **say so in the handoff**. Do not claim scene-backed validation you could not perform.

---

## Tool-Approval Policy

The MCP has two tiers of tools. Approve them differently.

### Auto-approve (read-only, safe to spam)

These inspect without mutating. Add to your allowlist so the agent isn't prompted every poll:

- `godot_editor_status`
- `godot_get_scene_tree`
- `godot_parse_scene`
- `godot_get_node_properties`
- `godot_list_directory`
- `godot_list_tests`
- `godot_get_project_info`
- `godot_get_open_scripts`
- `godot_get_current_script`
- `godot_get_selected_nodes`
- `godot_get_script_for_node`
- `godot_list_animations`
- `godot_get_animation`
- `godot_list_signals`
- `godot_list_connections`
- `godot_get_uid`
- `godot_get_profiler_data`
- `godot_get_stack_trace`
- `godot_get_locals`
- `godot_list_breakpoints`
- `godot_list_projects`
- `godot_list_export_presets`
- `godot_list_resources`
- `godot_read_resource`
- `godot_get_output`
- `godot_is_running`
- `godot_get_version`
- `godot_validate_script`
- `godot_detect_test_framework`
- `godot_take_screenshot`
- `godot_take_game_screenshot`

### Prompt every time (mutating or side-effectful)

Anything that starts with `add_`, `create_`, `set_`, `remove_`, `delete_`, `rename_`, `reparent_`, `duplicate_`, `move_`, `connect_`, `disconnect_`, `run_`, `stop_`, `step_`, `continue`, `write_`, `import_`, `export_`, `save_`, `open_scene`, `launch_editor`, `insert_code`, `load_sprite_in_file`, `update_uids`. Human signs off each time.

**Iterative exception:** during a tight loop (e.g. "tune this value, run, observe, repeat"), add `godot_run_scene` + `godot_stop_scene` to the session allowlist for that task and drop them on exit. Prompting on every iteration kills the feedback cycle.

---

## Path Conventions

- **Pass `res://` paths** to MCP tools (`res://car/sphere_car.tscn`, not `/Users/you/workspace/overlap/car/sphere_car.tscn`).
- **Pass absolute filesystem paths** to Read/Write/Edit (`/Users/you/workspace/overlap/car/sphere_car.gd`).
- **Never mix.** `res://` is a Godot-internal scheme; the MCP resolves it against the open project. The file tools don't understand it.

---

## Scene-File Fragility

`.tscn` and `.tres` are text, but they are not editor-stable text. The format encodes:

- Stable-ish node ids
- Subresource numbers that renumber when the file is re-saved
- Serialized Resource states that depend on script class registration
- External resource UIDs that change if you rewrite the file by hand

**Rules:**

1. **Prefer MCP over hand-editing.** `godot_set_property`, `godot_add_node`, `godot_reparent_node`, `godot_set_property_in_file` exist for this.
2. **If a `.tscn` must be edited as text, keep edits minimal and surgical.** Change one value, save, stop. Never reformat or reorder sections.
3. **After any scene edit, verify it still opens.** `godot_open_scene` or `godot_get_scene_tree` is enough — a corrupted scene fails loudly.
4. **After any `Resource` script refactor, clear the import cache** before the next web build: `rm -rf .godot` and reopen the editor. Desktop builds often forgive stale caches; web builds silently load defaults instead of stored overrides.

---

## Headless Validators Complement, Don't Replace, the Loop

The MCP loop catches runtime errors and visual feel. The headless validators catch correctness and regressions. Use both.

```bash
bash scripts/headless_check.sh                      # both per-controller validators
godot --headless --path . --script res://scripts/validate_physics_car.gd
godot --headless --path . --script res://scripts/validate_sphere_car.gd
```

See `AGENTS.md` → "Change Playbook" for when each validator is required.

---

## Common Workflows

### Add a node to a scene

```
godot_get_scene_tree                         # know what's there
godot_add_node  (type, name, parent_path)    # add
godot_set_property  (node, prop, value)      # configure
godot_save_scene                             # persist
godot_get_scene_tree                         # confirm it landed
```

### Change an exported property on a scene-instanced node

Prefer `godot_set_property_in_file` so the edit persists without opening the scene:

```
godot_set_property_in_file  (path, node, prop, value)
```

Verify:

```
godot_parse_scene  (path)    # inspect without opening
```

### Create a new hazard scene

```
godot_create_scene  (path, root_type)        # e.g. Area3D
godot_add_node                               # MeshInstance3D, CollisionShape3D, ...
godot_create_script                          # bind the hazard script
godot_set_property                           # wire up @export values
godot_save_scene
godot_run_scene  (main.tscn)                 # smoke-test
godot_get_output                             # check for errors
godot_stop_scene
```

### Run profiling for a frame-rate issue

```
godot_start_profiler
godot_run_scene
# ... let it run 10–30 seconds ...
godot_get_profiler_data
godot_stop_profiler
godot_stop_scene
```

---

## Anti-Patterns

- **Touching a scene without reading it first.** Your mental model of the tree is always stale. One `get_scene_tree` per change.
- **Hand-editing `.tscn` with Write/Edit because "it's just a property change."** The renumbering cost is one corrupted scene away. Use `godot_set_property_in_file`.
- **Claiming validation the editor didn't perform.** If `editor_status` was down, say so. Headless validators are a substitute for correctness, not for feel.
- **Auto-approving mutating tools.** `godot_run_scene` can hang the editor; `godot_remove_node` can delete work. Keep these behind the prompt.
- **Running two editor instances on the same MCP port.** The second one silently fails to bind. Use `worktrees` for how to parallelize.
- **Skipping `godot_stop_scene`.** An orphaned running scene keeps the editor locked and the MCP unresponsive.
- **Mixing `res://` and absolute paths.** The MCP doesn't resolve absolutes; the file tools don't resolve `res://`.

---

## Cross-References

- **debugging** — When MCP calls return unexpected state, follow the four-phase root-cause investigation before trying another command.
- **worktrees** — Running two Godot editors needs one MCP port per editor. Use `worktrees` for the port-conflict workaround.
- **AGENTS.md** — "I ran the scene and it worked" is only a valid handoff claim when you actually checked runtime output (`godot_get_output` or the equivalent MCP-backed output read).

---

## Project-Specific Notes (Overlap)

- Bridge port 6008 is defaulted in `addons/godot_mcp_bridge/bridge_server.gd` (`func start(port: int = 6008)`), not in `project.godot`. Two editors on the same port fight silently. To run two editors, change the port in the second worktree's `bridge_server.gd` (or close one).
- Scene-backed systems to validate after any change: `main.tscn`, `car/sphere_car.tscn`, `car/physics_car.tscn`, and the layout currently in use.
- After a `Resource` refactor (anything under `car/car_stats.gd`, `race/*_type.gd`, `track/track_*_definition.gd`), `rm -rf .godot` before the next web build or you'll ship stale defaults. See `AGENTS.md` → "Web Builds".
- The repo has two validators (`validate_physics_car.gd`, `validate_sphere_car.gd`) and `scripts/headless_check.sh` as the orchestrator. Use them — don't write new ones without good reason.
- Full working-rules and commit conventions surrounding this skill live in `AGENTS.md`.
