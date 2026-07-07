class_name Track
extends Node2D
## Base track script. Owns lap validity through its RouteTracker child:
## a lap is the authored route whose edge crossings you accumulated,
## closed at the start line. Cuts and unknown circuits never complete —
## the attempt just restarts. Timing lives in RaceState, not here.

signal lap_started
signal lap_completed(route_id: String)
signal checkpoint_crossed(index: int, total: int)

const TrackDefScript = preload("res://scenes/track/track_def.gd")
const TrackNetworkDefScript = preload("res://scenes/track/track_network_def.gd")
const RouteTrackerScript = preload("res://scenes/track/route_tracker.gd")
const SecretRoadScript = preload("res://scenes/track/secret_road.gd")

@export var def: TrackDefScript
@export var network: TrackNetworkDefScript

@onready var _tracker: RouteTrackerScript = $RouteTracker


func _ready() -> void:
	_tracker.network = network
	_tracker.lap_started.connect(lap_started.emit)
	_tracker.route_lap_completed.connect(_on_route_lap_completed)
	_tracker.edge_crossed.connect(func(count: int) -> void:
		checkpoint_crossed.emit(count - 1, _longest_route_edges()))
	for child in $Road.get_children():
		if child is SecretRoadScript:
			_tracker.line_crossed.connect(child.on_line_crossed)


## Belt over the physical gate bars: a route whose gates aren't all owned
## never certifies, so flanking a closed gate over grass earns nothing —
## no discovery, no PB, no fleet. RouteDef: gates "must all be owned
## before this route is drivable."
func _on_route_lap_completed(route_id: String) -> void:
	var route := network.find_route(route_id)
	if route != null:
		for gate_id in route.required_gates:
			if not Bank.is_gate_purchased(gate_id):
				return
	lap_completed.emit(route_id)


func _longest_route_edges() -> int:
	var longest := 0
	for route in network.routes:
		longest = maxi(longest, route.edges.size())
	return longest
