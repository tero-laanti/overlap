class_name DevProbeRoutes
extends RefCounted
## DevProbe's authored waypoint routes, split out to keep the probe
## scenario under the line ceiling. Pure data — the probe hands these to
## DevDriver as it advances through its phases. Archipelago v3 Home
## island (docs/MAP_DESIGN_V3.md §2); Port/Crag routes arrive with
## their islands.

## Hairpin apex / tree gap capture: the default reach corner-cuts both.
const CLIFF_REACH := 120.0

const RING: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(1950, -250),
	Vector2(2350, 300), Vector2(2650, 750), Vector2(2350, 1150),
	Vector2(1400, 1200),
]
## The T1 fork: don't brake, run straight into the sand bowl, sweep it
## counterclockwise, and merge back onto the riser heading north.
const DUNE: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2600, 1080), Vector2(-3600, 830),
	Vector2(-4450, 420), Vector2(-4870, -200), Vector2(-4520, -830),
	Vector2(-3550, -1010), Vector2(-2700, -960), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(1950, -250),
	Vector2(2350, 300), Vector2(2650, 750), Vector2(2350, 1150),
	Vector2(1400, 1200),
]
## Through the golden tree gap into the woods arc — the first crossing
## proves the secret trigger fires from real driving.
const FOREST: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1900, -1450), Vector2(-1990, -1620), Vector2(-2060, -1810),
	Vector2(-2250, -2100),
	Vector2(-2350, -2850), Vector2(-1650, -3300), Vector2(-800, -3150),
	Vector2(-550, -2400), Vector2(-1100, -1450),
	Vector2(0, -1380), Vector2(1000, -1450), Vector2(1900, -1250),
	Vector2(2300, -800), Vector2(1950, -250), Vector2(2350, 300),
	Vector2(2650, 750), Vector2(2350, 1150), Vector2(1400, 1200),
]
