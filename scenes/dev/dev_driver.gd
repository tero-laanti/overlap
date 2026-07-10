class_name DevDriver
extends RefCounted
## Waypoint autopilot shared by DevProbe and DevCalibrate: holds input
## actions toward the current waypoint, coasts into sharp turns, and
## backs straight out when pinned. Owns the held-action set — call
## release_all() before handing control back. Call drive() from
## _physics_process, NOT _process: decisions must track physics ticks
## so the bot behaves identically under Engine.time_scale (the
## OVERLAP_TIMESCALE fast-run knob).


## Dev runs go faster with OVERLAP_TIMESCALE=<n> in the environment
## (e.g. 8): compressed wall-clock, tick-identical simulation. Godot's
## time_scale alone makes each physics step integrate a BIGGER dt
## (sloppier sim, 8x fewer recording samples — cost a probe run);
## scaling physics_ticks_per_second with it keeps the per-step game dt
## at exactly 1/60 — more steps, not bigger steps.
static func apply_dev_time_scale() -> void:
	var raw := OS.get_environment("OVERLAP_TIMESCALE")
	if raw == "":
		return
	var scale := clampf(float(raw), 1.0, 32.0)
	Engine.time_scale = scale
	Engine.physics_ticks_per_second = roundi(60.0 * scale)
	# Never let the per-frame step clamp bind — a starved frame would
	# silently desync the game clock from the physics the car lives in.
	Engine.max_physics_steps_per_frame = maxi(8, roundi(scale) * 16)
	print("[DEV] time_scale=%.0fx (physics %d tps, step dt %.4f)" % [
		scale, Engine.physics_ticks_per_second,
		Engine.time_scale / Engine.physics_ticks_per_second])

const WAYPOINT_REACHED_DISTANCE := 240.0
const STEER_DEADZONE := 0.06
const COAST_ANGLE := 0.9
const COAST_MIN_SPEED := 550.0
const CarScript = preload("res://scenes/car/car.gd")

var car: CarScript
var waypoints: Array[Vector2] = []
var reach := WAYPOINT_REACHED_DISTANCE
## Where the route loops back to after the last waypoint. A one-way
## lead-in (island travel: ramp jump onto another landmass) lives at
## the front of the list; the lap circuit from loop_from on repeats.
var loop_from := 0

var _index := 0
var _held: Array[String] = []
var _elapsed := 0.0
var _stuck_time := 0.0
var _reverse_until := 0.0


## A tighter reach threads narrow mouths (tree gaps) at the cost of
## more correction steering.
func set_route(points: Array[Vector2], reach_distance := WAYPOINT_REACHED_DISTANCE,
		loop_start := 0) -> void:
	waypoints = points
	reach = reach_distance
	loop_from = loop_start
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
		_index += 1
		if _index >= waypoints.size():
			_index = loop_from
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
