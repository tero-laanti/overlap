class_name TrackNetworkDef
extends Resource
## The gate network of one world: crossing lines (one start line per
## island + one mid-edge line per segment), authored routes, and
## purchasable gates. RouteTracker consumes only this resource, so route
## detection is headless-testable and independent of scene geometry.
## Archipelago (MAP_DESIGN_V3 §3): each island has its own start line; a
## lap closes at the line it opened at, and every route names its
## island's line via RouteDef.start_line.

const CrossingLineDefScript = preload("res://scenes/track/crossing_line_def.gd")
const RouteDefScript = preload("res://scenes/track/route_def.gd")
const GateDefScript = preload("res://scenes/track/gate_def.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

## One entry per island; the first is where the car spawns.
@export var start_line_ids := PackedStringArray(["start"])
@export var crossing_lines: Array[CrossingLineDefScript] = []
@export var routes: Array[RouteDefScript] = []
@export var gates: Array[GateDefScript] = []
## Authored order matters: among rivals sharing a route it is the
## ladder order (earlier tiers must fall first).
@export var rivals: Array[RivalDefScript] = []


func is_start_line(line_id: String) -> bool:
	return line_id in start_line_ids


func find_route(route_id: String) -> RouteDefScript:
	for route in routes:
		if route.id == route_id:
			return route
	return null


func find_gate(gate_id: String) -> GateDefScript:
	for gate in gates:
		if gate.id == gate_id:
			return gate
	return null


func find_rival(rival_id: String) -> RivalDefScript:
	for rival in rivals:
		if rival.id == rival_id:
			return rival
	return null


## The authored route on this island (start line) whose edge sequence
## matches exactly, or null.
func match_route(edges: PackedStringArray, start_line: String) -> RouteDefScript:
	for route in routes:
		if route.start_line == start_line and route.edges == edges:
			return route
	return null
