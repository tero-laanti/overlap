class_name DevProbeRoutes
extends RefCounted
## DevProbe's authored waypoint routes, split out to keep the probe
## scenario under the line ceiling. Pure data — the probe hands these to
## DevDriver as it advances through its phases. Island v2 hub
## (docs/MAP_DESIGN_V2.md §2); annex routes return with their
## re-adaptation slices.

const RING: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(0, -1380), Vector2(1000, -1450),
	Vector2(1900, -1250), Vector2(2300, -800), Vector2(1950, -250),
	Vector2(2350, 300), Vector2(2650, 750), Vector2(2350, 1150),
	Vector2(1400, 1200),
]
const CUT: Array[Vector2] = [
	Vector2(-1500, 1200), Vector2(-2450, 1080), Vector2(-2620, 700),
	Vector2(-2350, 100), Vector2(-2700, -700), Vector2(-2350, -1250),
	Vector2(-1000, -1450), Vector2(-200, -1390), Vector2(450, -1360),
	Vector2(500, -900), Vector2(500, 0), Vector2(500, 1000),
	Vector2(0, 1200),
]
