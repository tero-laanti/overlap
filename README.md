# Overlap

Overlap is an early-stage Godot 4.6 arcade racing game prototype. The current focus is driving feel, drift mechanics, and proving out the core vehicle controller before expanding into track design, progression, or presentation polish.

## Current State

- Arcade car controller with drift system (the "Big Lie" — drifting preserves and adds speed)
- Rear-wheel drift smoke feedback that only emits while the car is sliding
- Surface-dependent handling for tarmac, sand, and grass
- Procedural test track with walls and a closed-loop centerline
- Progress-based lap counter with a virtual checkpoint and HUD
- Repeatable round loop with countdown, lap timer, multiplier, and lap-reward currency HUD
- Basic coin collectibles with multiplier-scaled payouts and per-lap respawn
- Round-end pit stop that can buy extra starting time or queue a Boost Pad for track placement before the next round
- Dynamic follow camera with speed-based zoom
- Jolt Physics at 120Hz tick rate
- Godot MCP Bridge for editor automation

## Getting Started

Requires Godot 4.6 with Jolt Physics (built-in). Clone the repo, open `project.godot` in the Godot editor, and press F5 to run.

## Project Structure

```
car/          Car controller, stats resource, and tuning data
camera/       Camera systems
race/         Race-state systems such as lap tracking
track/        Track generation and layout
ui/           HUD and prototype overlays
addons/       Editor plugins (MCP bridge)
docs/         Design notes and explorations (planned)
```

## Design Direction

The driving model is intentionally arcade — no suspension simulation, no tire model. The car is a RigidBody3D constrained to a ground plane with force-based acceleration and direct angular velocity steering. Drift state reduces lateral grip and adds a forward boost, rewarding the player for controlled slides.

The prototype should answer:
- Does the drift-boost loop feel rewarding at speed?
- Can the track layout create interesting drift chains?
- What progression or challenge structure fits around this core?

## Docs Structure

- `AGENTS.md`: canonical agent instructions and repo guardrails.
- `CLAUDE.md`: thin compatibility pointer for tools that still look for that filename.
- `docs/explorations/`: exploratory working notes for concept development and idea-bouncing (planned).

Exploration docs are intentionally non-authoritative. Ideas graduate into authoritative docs only after they are decided and ready to guide implementation.
