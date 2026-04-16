# Overlap — Game Design

## Core Loop

Race laps on a circuit under a timer. Each completed lap increases a multiplier, making every subsequent lap more valuable. Between rounds, spend earnings to place beneficial elements on the track, draft and place hazards, and watch the track mutate longer. The run ends when the track has grown too long and hazardous to sustain earnings.

### Drive Phase

- Lap-based multiplier: starts at x1, +1 per lap. Collectibles scale with it.
- Timer pressure creates "one more lap" greed.
- Track contains both player-placed positives and negatives.

### Pit Stop Phase (between rounds)

1. **Buy positives** — boost pads, coins, timer extensions. Player chooses placement.
2. **Draft a negative** — pick 1 of 2 hazards to place. The lesser evil.
3. **Track mutation** (every N rounds) — circuit grows longer. Laps take more time, multiplier grows slower, earnings pressure increases.

### Run Arc

Round 1 is gentle: simple track, generous timer, no hazards. Difficulty escalates through player choices. Soft fail state — earnings collapse, not a hard game over. 10-20 minute runs. Restarting should feel painless.

## Design Principles

1. **Driving feel first.** The car must feel excellent before anything else matters.
2. **Pressure through escalation.** Readable hazards and harder asks, not stat growth.
3. **Upgrades change gameplay, not stats.** "Boost ability" good, "+5% speed" bad.
4. **Player-driven difficulty.** You placed the hazards. You chose which negative.
5. **Prototype before committing.** No mechanic is settled until playtested.
6. **Juice is handling work, not polish.** Screen shake, particles, sound are part of how the car feels.
7. **Build physics toward fun, not down from realism.** Simple fake forces over simulation.

## Driving Feel

- Simple arcade physics. No tire simulation, no slip angle math.
- Drift should never feel like a punishment. Exact drift reward model is open — discover through playtesting.
- Camera should keep the car readable and never let orientation become confusing. Exact perspective is being explored.
- Constant acceleration. Rarely force the player to fully stop.
- Responsive instantly — no input lag, no sluggish turning.

## Car Classes (future — design around it, don't build yet)

4 vehicle types with 20-30% parameter variance. Each takes different racing lines.

| Class | Identity | Feel |
|-------|----------|------|
| Speedster | Glass cannon | High speed, low grip, fragile |
| Tank | Battering ram | Slow, high grip, heavy |
| Drifter | Style machine | Medium speed, low drift threshold |
| Balanced | Jack of all trades | No extremes, the learning car |

Use exported Resource scripts for tuning so classes are easy to add.

## Current Phase

Phase 1: Core racing feel. Grey box car, test track, camera. Get the driving to feel great before building any systems on top of it.

## What Not To Do

- Don't build realistic physics. Build fun physics.
- Don't add combat, opponents, or weapons yet.
- Don't procedurally generate tracks. Every track piece is hand-authored.
- Don't add meta-progression. One run needs to be fun first.
- Don't over-engineer architecture. Get it playable.

## Inspirations

Balatro (multiplier greed), Turbo Sliders (top-down feel), Vampire Survivors (roguelite structure), Hades (run pacing), Burnout (class differentiation).
