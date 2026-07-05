# Overlap — Vision

**One line:** IGTAP, but a racer. You drive laps by hand; every lap you're
proud of becomes a ghost clone that drives it forever and earns you money.

## Core loop

1. **Drive.** Top-down 2D arcade driving on a closed circuit. Inputs are
   recorded while you drive.
2. **Hire your ghost.** A completed lap can be assigned to a ghost slot. The
   ghost replays that exact lap endlessly.
3. **Earn.** Each ghost lap pays out: `payout = track value / lap time`.
   Faster laps and better tracks earn more. Income accrues while playing and
   while away (offline = income rate × elapsed time).
4. **Upgrade.** Money buys car upgrades (speed, grip, boost), more ghost
   slots, new cars, and new tracks.
5. **Re-drive.** Better cars set faster laps → replace old ghosts with faster
   ones → income compounds. Prestige layer resets for multipliers (later).

The emotional hook: the track slowly fills with *you*. Every ghost on screen
is a lap you actually drove. Progress is visible as traffic.

## Pillars

1. **Driving feel first.** If steering isn't fun in the first 10 seconds,
   nothing else matters. (Inherited from Overlap 1 — the one thing it got
   unambiguously right.)
2. **Ghosts are the spectacle.** The screen filling with your own past laps
   IS the progress bar. Ghost count and visual density should always be
   rising.
3. **Numbers go up, cheaply.** The economy is pure math over recorded lap
   times. No simulation needed — which keeps it exact for offline earnings.
4. **Every session ends better than it started.** Either you set a faster
   lap, bought something, or unlocked something. No dead sessions.

## What this is NOT (scope fence)

- Not Overlap 1: no round timer, no pit-stop draft, no hazard placement, no
  track mutation. That game exists in ../overlap; we are not rebuilding it.
- No opponents/AI racing in v1. Ghosts don't collide with you or each other.
- No multiplayer, no procedural tracks in v1.

## References

- Concept: IGTAP (idle platformer where clones replay your runs for income).
- Car feel: ../topdown (Unity) — forward/lateral velocity split with drift
  factor; playtested as "super nice". Same technique as the "2D Top Down
  Racer with Godot 4.5+" YouTube series.
- Driving pillar & what to avoid structurally: ../overlap (see CLAUDE.md
  hard rules).
