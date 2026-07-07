class_name DevProbeRoutes
extends RefCounted
## DevProbe's authored waypoint routes, split out to keep the probe
## scenario under the line ceiling. Pure data — the probe hands these to
## DevDriver as it advances through its phases.

## Hairpin apex capture: the default reach radius corner-cuts the ladder.
const CLIFF_REACH := 120.0

const RING: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(1050, -550), Vector2(1050, 550),
]
const CUT: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(300, -550), Vector2(300, -100), Vector2(300, 550),
]
const PETAL: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1260, 300), Vector2(-1520, 0),
	Vector2(-1260, -300), Vector2(-1050, -550),
	Vector2(1050, -550), Vector2(1050, 550),
]
## Up the NE approach, the hairpin ladder, the lighthouse hairpin, the
## esses, then the descent straight through the X into the chord.
const CLIMB: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(600, -550), Vector2(1100, -570),
	Vector2(1400, -790), Vector2(1540, -1120),
	Vector2(2250, -1120), Vector2(2400, -1180), Vector2(2420, -1290),
	Vector2(2400, -1400), Vector2(2250, -1460),
	Vector2(1650, -1460), Vector2(1500, -1520), Vector2(1480, -1630),
	Vector2(1500, -1740), Vector2(1650, -1800),
	Vector2(2250, -1800), Vector2(2440, -1880), Vector2(2470, -2010),
	Vector2(2440, -2140), Vector2(2250, -2220),
	Vector2(1720, -2280), Vector2(1280, -2160), Vector2(860, -2300),
	Vector2(520, -2150),
	Vector2(260, -1750), Vector2(230, -1350), Vector2(260, -950),
	Vector2(300, -450), Vector2(300, 100), Vector2(300, 500),
]
