class_name DevDriver
extends RefCounted
## Waypoint autopilot shared by DevProbe and DevCalibrate: holds input
## actions toward the current waypoint, coasts into sharp turns, and
## backs straight out when pinned. Owns the held-action set — call
## release_all() before handing control back.

const WAYPOINT_REACHED_DISTANCE := 240.0
const STEER_DEADZONE := 0.06
const COAST_ANGLE := 0.9
const COAST_MIN_SPEED := 550.0
const CarScript = preload("res://scenes/car/car.gd")

var car: CarScript
var waypoints: Array[Vector2] = []
var reach := WAYPOINT_REACHED_DISTANCE

var _index := 0
var _held: Array[String] = []
var _elapsed := 0.0
var _stuck_time := 0.0
var _reverse_until := 0.0


## A tighter reach threads narrow mouths (tree gaps) at the cost of
## more correction steering.
func set_route(points: Array[Vector2], reach_distance := WAYPOINT_REACHED_DISTANCE) -> void:
	waypoints = points
	reach = reach_distance
	_index = 0


func drive(delta: float) -> void:
	_elapsed += delta
	if car == null or waypoints.is_empty():
		return
	# Nose-in-wall recovery: back straight up for a moment, then resume.
	if _elapsed < _reverse_until:
		_hold(["brake"])
		return
	if car.velocity.length() < 40.0:
		_stuck_time += delta
		if _stuck_time > 2.0:
			_stuck_time = 0.0
			_reverse_until = _elapsed + 1.3
			return
	else:
		_stuck_time = 0.0

	var target := waypoints[_index]
	if car.global_position.distance_to(target) < reach:
		_index = (_index + 1) % waypoints.size()
		target = waypoints[_index]

	var heading := car.rotation - PI / 2.0
	var desired := (target - car.global_position).angle()
	var error := angle_difference(heading, desired)

	var wanted: Array[String] = []
	if error > STEER_DEADZONE:
		wanted.append("steer_right")
	elif error < -STEER_DEADZONE:
		wanted.append("steer_left")
	# Brake into sharp turns: fast cars have turn radii wider than the
	# waypoint capture radius and would otherwise orbit forever.
	var sharp_turn := absf(error) > COAST_ANGLE
	if sharp_turn and car.velocity.length() > COAST_MIN_SPEED:
		wanted.append("brake")
	else:
		wanted.append("accelerate")
	_hold(wanted)


func release_all() -> void:
	for action in _held:
		Input.action_release(action)
	_held.clear()


func _hold(wanted: Array[String]) -> void:
	for action in _held.duplicate():
		if action not in wanted:
			Input.action_release(action)
			_held.erase(action)
	for action in wanted:
		if action not in _held:
			Input.action_press(action)
			_held.append(action)
