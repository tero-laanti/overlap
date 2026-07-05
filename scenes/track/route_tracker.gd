class_name RouteTracker
extends Node
## Detects crossing-line events analytically: the player car's per-tick
## movement segment is tested against every line in the network def —
## tunnel-proof at any speed, no Area2D (see docs research). Owns the lap
## edge accumulator: forward edge crossings append, backing over the last
## edge pops it (U-turn), any other backward crossing dirties the lap.
## Crossing the start line closes a clean, authored edge sequence into a
## route lap and always begins a fresh lap. Timing lives in RaceState.

signal lap_started
signal route_lap_completed(route_id: String)
signal edge_crossed(count: int)

const TrackNetworkDefScript = preload("res://scenes/track/track_network_def.gd")
const CrossingLineDefScript = preload("res://scenes/track/crossing_line_def.gd")

## A crossed line stays disarmed until the car is this far from it, so
## skimming along a line cannot double-fire.
const REARM_DISTANCE := 48.0

var network: TrackNetworkDefScript

var _car: Node2D
var _prev_pos := Vector2.ZERO
var _have_prev := false
var _edges := PackedStringArray()
var _lap_active := false
var _dirty := false
var _disarmed := {}


func _physics_process(_delta: float) -> void:
	if network == null:
		return
	if _car == null:
		_car = get_tree().get_first_node_in_group("player_car")
		if _car == null:
			return
	var pos := _car.global_position
	if not _have_prev:
		_prev_pos = pos
		_have_prev = true
		return
	if pos != _prev_pos:
		for line: CrossingLineDefScript in network.crossing_lines:
			_test_line(line, _prev_pos, pos)
	_prev_pos = pos


func _test_line(line: CrossingLineDefScript, from: Vector2, to: Vector2) -> void:
	if _disarmed.get(line.id, false):
		var closest := Geometry2D.get_closest_point_to_segment(to, line.a, line.b)
		if closest.distance_to(to) >= REARM_DISTANCE:
			_disarmed[line.id] = false
		return
	if not Geometry2D.segment_intersects_segment(from, to, line.a, line.b):
		return
	_disarmed[line.id] = true
	var forward := (line.b - line.a).cross(to - from) > 0.0
	_on_crossing(line.id, forward)


func _on_crossing(line_id: String, forward: bool) -> void:
	if line_id == network.start_line_id:
		if forward:
			_close_or_start_lap()
		return
	if not _lap_active:
		return
	if forward:
		_edges.append(line_id)
		edge_crossed.emit(_edges.size())
	elif _edges.size() > 0 and _edges[_edges.size() - 1] == line_id:
		_edges.remove_at(_edges.size() - 1)
	else:
		_dirty = true


## A clean lap whose edges match an authored route completes it; anything
## else (dirty, unknown circuit) is silently discarded. Either way the
## next lap attempt starts immediately.
func _close_or_start_lap() -> void:
	if _lap_active and not _dirty:
		var route := network.match_route(_edges)
		if route != null:
			route_lap_completed.emit(route.id)
	_lap_active = true
	_dirty = false
	_edges = PackedStringArray()
	lap_started.emit()
