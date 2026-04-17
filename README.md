# Overlap

Overlap is an early-stage Godot 4.6 arcade racing game prototype built around an arcade drift controller, lap-multiplier greed, and a round-by-round pit stop loop. See [DESIGN.md](DESIGN.md) for the game vision.

## Current State

- Arcade car controller with drift system (the "Big Lie" — drifting preserves and adds speed)
- Rear-wheel drift smoke feedback that only emits while the car is sliding
- Surface-dependent handling for tarmac, sand, and grass
- Tile-authored starter tracks stitched into a closed-loop centerline with generated walls and surfaces
- Progress-based lap counter with a virtual checkpoint and HUD
- Repeatable round loop with countdown, lap timer, multiplier, and lap-reward currency HUD
- Basic coin collectibles with multiplier-scaled payouts, per-lap respawn, and runtime round-start placement on the active track
- Registry-driven pit stop with three positive offers per round (utility, greed, handling), including permanent Time Bank purchases plus placeable Boost Pads, Coin Gates, Drift Ribbons, and Wash Gates
- Shaped hazard draft with one line-tax and one hard-reroute option, including Oil Slicks, Slow Zones, Gravel Spills, Crosswind Fans, Wall Barriers, and Cone Chicanes
- Queue-and-place track setup flow where bought positives are placed on the track before the drafted hazard and then persist for the rest of the run
- Between-round track evolution: starting at round 2, one straight is spliced into a detour module so laps grow longer over the course of a run
- Dynamic follow camera with speed-based zoom
- Jolt Physics at 120Hz tick rate
- Godot MCP Bridge for editor automation

## Getting Started

Requires Godot 4.6 with Jolt Physics (built-in). Clone the repo, open `project.godot` in the Godot editor, and press F5 to run.

## Headless Validation

On a fresh clone, bootstrap Godot's global `class_name` registry before running plain headless validation:

1. `godot --headless --editor --path . --quit`
2. `godot --headless --path . --quit-after 3`

After that first editor-style scan, use your normal headless command for follow-up checks.

If you want the repo to do both steps for you, run `scripts/headless_check.sh` and set `GODOT_BIN` if your Godot executable is not on `PATH`.

## Project Structure

```
car/          Car controller, stats resource, and tuning data
camera/       Camera systems
race/         Race-state systems such as lap tracking
track/        Track tiles, starter layouts, and generated track runtime
ui/           HUD and prototype overlays
addons/       Editor plugins (MCP bridge)
docs/         Design notes and explorations
scripts/      Local validation helpers
```

## Design Direction

The driving model is intentionally arcade. The car is a custom `RigidBody3D`
controller with query-based suspension, body-level acceleration, and direct
steering control instead of a full tire model. Drift state reduces lateral grip
and adds a forward boost, rewarding the player for controlled slides.

The prototype should answer:
- Does the drift-boost loop feel rewarding at speed?
- Can the track layout create interesting drift chains?
- What progression or challenge structure fits around this core?

## Deployment to itch.io

The repo ships builds to itch.io via GitHub Actions ([.github/workflows/deploy.yml](.github/workflows/deploy.yml)). Four channels are pushed per run: `html`, `windows`, `linux`, `macos`.

### Triggering a deploy

- **Tagged release**: `git tag v0.1.0 && git push --tags`.

Butler versions the build as the tag name on tagged runs, or the commit SHA on manual runs.

## Docs Structure

- `AGENTS.md`: canonical agent instructions and repo guardrails.
- `CLAUDE.md`: thin compatibility pointer for tools that still look for that filename.
- `docs/explorations/`: exploratory working notes for concept development and idea-bouncing.

Exploration docs are intentionally non-authoritative. Ideas graduate into authoritative docs only after they are decided and ready to guide implementation.
