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

@export var def: TrackDefScript
@export var network: TrackNetworkDefScript

@onready var _tracker: RouteTrackerScript = $RouteTracker


func _ready() -> void:
	_tracker.network = network
	_tracker.lap_started.connect(lap_started.emit)
	_tracker.route_lap_completed.connect(lap_completed.emit)
	_tracker.edge_crossed.connect(func(count: int) -> void:
		checkpoint_crossed.emit(count - 1, _longest_route_edges()))


func _longest_route_edges() -> int:
	var longest := 0
	for route in network.routes:
		longest = maxi(longest, route.edges.size())
	return longest
