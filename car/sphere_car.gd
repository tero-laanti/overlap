class_name SphereCar
extends Car

## Arcade sphere-vehicle movement ported from
## https://github.com/KenneyNL/Starter-Kit-Racing (scripts/vehicle.gd) and
## tuned for punchier feel. The hidden `PhysicsProxy` `RigidBody3D` is a
## rolling sphere; this script accumulates drive torque in `_physics_process`
## and positions the `Car` root to follow the sphere each tick.

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
const DRIFT_ENTER_LATERAL_SPEED := 4.0
const DRIFT_EXIT_LATERAL_SPEED := 2.0
const DRIFT_MIN_FORWARD_SPEED := 3.0
## Body Y offset baked into the old `sphere_car.tscn` transform; kept here
## so `Car._spawn_selected_body` can apply it on top of each `CarOption`'s
## intrinsic body transform.
const BODY_BASE_Y_OFFSET := -0.25

var _input: Vector2 = Vector2.ZERO  # x = +right steering, y = +forward throttle
var _linear_speed: float = 0.0
var _angular_speed: float = 0.0
var _visual_root_rest_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	super._ready()
	if _visual_root != null:
		_visual_root_rest_transform = _visual_root.transform
	_teleport_sphere_to(global_transform)
	if _physics_proxy != null:
		_physics_proxy.reset_physics_interpolation()
	reset_physics_interpolation()


func _get_body_base_y_offset() -> float:
	return BODY_BASE_Y_OFFSET


func _physics_process(delta: float) -> void:
	if _physics_proxy == null:
		return

	_update_ground_probe()
	_sample_inputs()

	# Always turn in the direction pressed. No reverse-inversion.
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
	_physics_proxy.angular_velocity += -global_basis.x * (_linear_speed * DRIVE_TORQUE_MULTIPLIER) * delta

	global_position = _physics_proxy.global_position - Vector3(0.0, SPHERE_CENTER_HEIGHT, 0.0)
	_align_visual_to_ground()
	_update_drift_state()
	if _visual_pose != null:
		_visual_pose.tick_wheels(delta)


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
		# throttle because the engine needs traction.
		_input.x = raw_steer * AIR_STEER_FACTOR
		_input.y = 0.0
	# Legacy public convention: `+left -right` (see AGENTS.md direction table).
	steering_input = -raw_steer
	throttle_input = raw_throttle


func _update_ground_probe() -> void:
	if _ground_probe == null or _physics_proxy == null:
		is_grounded = false
		ground_normal = Vector3.UP
		return

	_ground_probe.global_position = _physics_proxy.global_position
	_ground_probe.force_raycast_update()
	is_grounded = _ground_probe.is_colliding()
	ground_normal = _ground_probe.get_collision_normal() if is_grounded else Vector3.UP


func _update_drift_state() -> void:
	if not is_grounded or _physics_proxy == null:
		if is_drifting:
			is_drifting = false
			drift_ended.emit()
		return

	var v: Vector3 = _physics_proxy.linear_velocity
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
	if _physics_proxy == null:
		return
	_physics_proxy.linear_velocity = Vector3.ZERO
	_physics_proxy.angular_velocity = Vector3.ZERO
	_physics_proxy.global_transform = Transform3D(
		Basis.IDENTITY,
		root_transform.origin + Vector3(0.0, SPHERE_CENTER_HEIGHT, 0.0),
	)


# -- Overrides over base defaults.

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
	# `_align_visual_to_ground` accumulates tilt on VisualRoot over a run.
	# Without this restore the body re-interpolates back to upright over
	# ~10 physics ticks after every respawn, reading as a drunken lean.
	if _visual_root != null:
		_visual_root.transform = _visual_root_rest_transform
	_teleport_sphere_to(spawn_transform)
	if _physics_proxy != null:
		_physics_proxy.sleeping = false
		_physics_proxy.reset_physics_interpolation()
	reset_physics_interpolation()


func set_controls_enabled(is_enabled: bool) -> void:
	super.set_controls_enabled(is_enabled)
	if not controls_enabled:
		_input = Vector2.ZERO


func set_frozen(should_freeze: bool) -> void:
	super.set_frozen(should_freeze)
	if should_freeze:
		_linear_speed = 0.0
		_angular_speed = 0.0
