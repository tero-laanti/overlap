class_name Car
extends Node3D

# Arcade sphere-vehicle movement ported from
# https://github.com/KenneyNL/Starter-Kit-Racing (scripts/vehicle.gd) and then
# tuned for punchier arcade feel: stronger drive torque, snappier steering,
# partial air control, and a simple lateral-slip drift detector so
# `drift_started` / `drift_ended` still mean something.
#
# Structure: the hidden `PhysicsProxy` `RigidBody3D` is the rolling sphere.
# `Car` follows its world position each physics tick and carries the yaw
# heading the rest of the game reads via `global_basis`.

const DRIVE_TORQUE_MULTIPLIER := 320.0
const STEERING_LERP_RATE := 8.0
const STEERING_MULTIPLIER := 5.5
const STEERING_GRIP_MIN := 0.2
const ACCELERATION_LERP_RATE := 9.0
const BRAKE_LERP_RATE := 14.0
const REVERSE_LERP_RATE := 3.5
const REVERSE_FRACTION := 0.35
const AIR_STEER_FACTOR := 0.4
const GROUND_ALIGN_LERP := 0.2
const GROUND_NORMAL_MATCH_THRESHOLD := 0.5
const SPHERE_CENTER_HEIGHT := 0.5
# Lateral slip speed (m/s) needed to enter / leave the drift state.
const DRIFT_ENTER_LATERAL_SPEED := 4.0
const DRIFT_EXIT_LATERAL_SPEED := 2.0
const DRIFT_MIN_FORWARD_SPEED := 3.0

signal drift_started
signal drift_ended
signal body_entered(body: Node)
signal body_exited(body: Node)
signal body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int)

@export var stats: CarStats

# Public state that other scripts read. Kept for API compatibility with the
# previous controller.
var steering_input: float = 0.0
var throttle_input: float = 0.0
var is_drifting: bool = false
var controls_enabled: bool = true
var is_grounded: bool = false
var ground_normal: Vector3 = Vector3.UP

var linear_velocity: Vector3:
	get:
		if _sphere == null:
			return Vector3.ZERO
		return _sphere.linear_velocity
	set(value):
		if _sphere != null:
			_sphere.linear_velocity = value

var angular_velocity: Vector3:
	get:
		if _sphere == null:
			return Vector3.ZERO
		return _sphere.angular_velocity
	set(value):
		if _sphere != null:
			_sphere.angular_velocity = value

var _input: Vector2 = Vector2.ZERO  # x = +right steering, y = +forward throttle
var _linear_speed: float = 0.0
var _angular_speed: float = 0.0
var _is_frozen: bool = false

@onready var _sphere: CarPhysicsProxy = get_node_or_null(^"PhysicsProxy") as CarPhysicsProxy
@onready var _ground_probe: RayCast3D = get_node_or_null(^"GroundProbe") as RayCast3D
@onready var _visual_root: Node3D = get_node_or_null(^"VisualRoot") as Node3D


func _ready() -> void:
	if stats == null:
		stats = load("res://car/default_stats.tres")
	if _sphere != null:
		_sphere.bind_car(self)
		if _ground_probe != null:
			_ground_probe.add_exception(_sphere)
	_teleport_sphere_to(global_transform)
	# The sphere was just teleported; without this the first frame interpolates
	# from its pre-ready world origin.
	if _sphere != null:
		_sphere.reset_physics_interpolation()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if _sphere == null:
		return

	_update_ground_probe()
	_sample_inputs()

	# Always turn the car in the direction pressed. Kenney's original flips
	# sign while reversing (real-car steering); for arcade predictability we
	# keep "press right = rotate right" regardless of motion direction.
	var direction: float = 1.0
	var steering_grip: float = clampf(absf(_linear_speed), STEERING_GRIP_MIN, 1.0)
	var target_angular: float = -_input.x * steering_grip * STEERING_MULTIPLIER * direction
	_angular_speed = lerpf(_angular_speed, target_angular, delta * STEERING_LERP_RATE)

	rotate_y(_angular_speed * delta)

	var target_speed: float = _input.y
	if target_speed < 0.0 and _linear_speed > 0.01:
		_linear_speed = lerpf(_linear_speed, 0.0, delta * BRAKE_LERP_RATE)
	elif target_speed < 0.0:
		_linear_speed = lerpf(_linear_speed, target_speed * REVERSE_FRACTION, delta * REVERSE_LERP_RATE)
	else:
		_linear_speed = lerpf(_linear_speed, target_speed, delta * ACCELERATION_LERP_RATE)

	# Roll torque around the car's right axis. `+global_basis.x` would roll the
	# sphere toward `+Z` (backward in Godot's `-Z = forward` convention), so
	# negate. Kenney's original uses `+basis.x` because their car model treats
	# `+Z` as forward; our sedan GLB flips that back via its Body scale.
	_sphere.angular_velocity += -global_basis.x * (_linear_speed * DRIVE_TORQUE_MULTIPLIER) * delta

	global_position = _sphere.global_position - Vector3(0.0, SPHERE_CENTER_HEIGHT, 0.0)
	_align_visual_to_ground()
	_update_drift_state()


func _sample_inputs() -> void:
	if not controls_enabled or _is_frozen:
		_input = Vector2.ZERO
		steering_input = 0.0
		throttle_input = 0.0
		return

	# +x when steering right, +y when throttling forward. `get_axis(neg, pos)`
	# returns `strength(pos) - strength(neg)`.
	var raw_steer: float = Input.get_axis("steer_left", "steer_right")
	var raw_throttle: float = Input.get_axis("brake", "throttle")
	if is_grounded:
		_input.x = raw_steer
		_input.y = raw_throttle
	else:
		# Partial steering in the air so the player can line up landings; no
		# throttle — the engine needs traction.
		_input.x = raw_steer * AIR_STEER_FACTOR
		_input.y = 0.0
	# Legacy public convention: `+left -right` (see AGENTS.md direction table).
	steering_input = -raw_steer
	throttle_input = raw_throttle


func _update_ground_probe() -> void:
	if _ground_probe == null:
		is_grounded = false
		ground_normal = Vector3.UP
		return

	_ground_probe.global_position = _sphere.global_position
	_ground_probe.force_raycast_update()
	is_grounded = _ground_probe.is_colliding()
	if is_grounded:
		ground_normal = _ground_probe.get_collision_normal()
	else:
		ground_normal = Vector3.UP


func _update_drift_state() -> void:
	if not is_grounded or _sphere == null:
		if is_drifting:
			is_drifting = false
			drift_ended.emit()
		return

	var v: Vector3 = _sphere.linear_velocity
	var forward: Vector3 = -global_basis.z
	var right: Vector3 = global_basis.x
	forward.y = 0.0
	right.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	right = right.normalized()
	var forward_speed: float = v.dot(forward)
	var lateral_speed: float = absf(v.dot(right))

	var should_drift: bool = is_drifting
	if is_drifting:
		if lateral_speed < DRIFT_EXIT_LATERAL_SPEED or forward_speed < DRIFT_MIN_FORWARD_SPEED:
			should_drift = false
	elif lateral_speed > DRIFT_ENTER_LATERAL_SPEED and forward_speed > DRIFT_MIN_FORWARD_SPEED:
		should_drift = true

	if should_drift == is_drifting:
		return
	is_drifting = should_drift
	if is_drifting:
		drift_started.emit()
	else:
		drift_ended.emit()


func _align_visual_to_ground() -> void:
	if _visual_root == null or not is_grounded:
		return
	if ground_normal.dot(_visual_root.global_basis.y) <= GROUND_NORMAL_MATCH_THRESHOLD:
		return

	var aligned := _align_basis_to_normal(_visual_root.global_transform, ground_normal)
	_visual_root.global_transform = _visual_root.global_transform.interpolate_with(aligned, GROUND_ALIGN_LERP).orthonormalized()


static func _align_basis_to_normal(xform: Transform3D, new_up: Vector3) -> Transform3D:
	xform.basis.y = new_up
	xform.basis.x = -xform.basis.z.cross(new_up)
	xform.basis = xform.basis.orthonormalized()
	return xform


func _teleport_sphere_to(root_transform: Transform3D) -> void:
	if _sphere == null:
		return
	_sphere.linear_velocity = Vector3.ZERO
	_sphere.angular_velocity = Vector3.ZERO
	_sphere.global_transform = Transform3D(
		Basis.IDENTITY,
		root_transform.origin + Vector3(0.0, SPHERE_CENTER_HEIGHT, 0.0),
	)


# -- Public API preserved so hazards, boost pads, HUD, pit stop, etc. keep
# compiling. Grip / speed-cap modifier hooks are still no-ops; bringing those
# back will need a matching hook in the new physics model.

func reset_to_transform(spawn_transform: Transform3D) -> void:
	_linear_speed = 0.0
	_angular_speed = 0.0
	_input = Vector2.ZERO
	steering_input = 0.0
	throttle_input = 0.0
	is_grounded = false
	ground_normal = Vector3.UP
	if is_drifting:
		is_drifting = false
		drift_ended.emit()
	global_transform = spawn_transform
	_teleport_sphere_to(spawn_transform)
	if _sphere != null:
		_sphere.sleeping = false
		_sphere.reset_physics_interpolation()
	reset_physics_interpolation()


func set_controls_enabled(is_enabled: bool) -> void:
	controls_enabled = is_enabled
	if not controls_enabled:
		_input = Vector2.ZERO
		steering_input = 0.0
		throttle_input = 0.0


func set_frozen(should_freeze: bool) -> void:
	_is_frozen = should_freeze
	if _sphere == null:
		return
	_sphere.freeze = should_freeze
	if should_freeze:
		_sphere.linear_velocity = Vector3.ZERO
		_sphere.angular_velocity = Vector3.ZERO
		_linear_speed = 0.0
		_angular_speed = 0.0
	else:
		_sphere.sleeping = false


func apply_forward_boost(boost_speed: float) -> void:
	if boost_speed <= 0.0 or _sphere == null:
		return
	var forward: Vector3 = -global_basis.z
	_sphere.linear_velocity += forward * boost_speed
	_sphere.sleeping = false


func apply_planar_velocity_delta(delta_velocity: Vector3) -> void:
	if _is_frozen or _sphere == null:
		return
	var planar: Vector3 = delta_velocity
	planar.y = 0.0
	_sphere.linear_velocity += planar
	_sphere.sleeping = false


func apply_grip_penalty(_multiplier: float, _duration: float) -> void:
	pass


func apply_grip_bonus(_multiplier: float, _duration: float) -> void:
	pass


func set_speed_cap(_factor: float) -> void:
	pass


func clear_speed_cap() -> void:
	pass


func clear_temporary_handling_modifiers() -> void:
	pass


func get_physics_proxy() -> CarPhysicsProxy:
	return _sphere


func has_full_ground_support() -> bool:
	return is_grounded


func get_support_up_axis() -> Vector3:
	return ground_normal if is_grounded else Vector3.UP


func get_drive_forward_vector(_up_axis: Vector3) -> Vector3:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


func get_heading_forward() -> Vector3:
	return get_drive_forward_vector(Vector3.UP)


# -- Signal relays used by CarPhysicsProxy.

func _relay_proxy_body_entered(body: Node) -> void:
	body_entered.emit(body)


func _relay_proxy_body_exited(body: Node) -> void:
	body_exited.emit(body)


func _relay_proxy_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	body_shape_entered.emit(body_rid, body, body_shape_index, local_shape_index)
