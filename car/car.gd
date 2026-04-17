class_name Car
extends RigidBody3D


class WheelState:
	var hardpoint: Marker3D
	var local_position: Vector3
	var grounded: bool = false
	var suspension_length: float = 0.0
	var compression_ratio: float = 0.0
	var support_force: float = 0.0
	var normal: Vector3 = Vector3.UP

	func _init(new_hardpoint: Marker3D) -> void:
		hardpoint = new_hardpoint
		local_position = new_hardpoint.position


@export var stats: CarStats

const SURFACE_PROVIDER_GROUP := &"surface_provider"
const DRIFT_FEEDBACK_NODE := "DriftFeedback"
const CAR_AUDIO_NODE := "CarAudio"
const TRACK_SURFACE_COLLISION_LAYER := 3
const GROUND_MIN_NORMAL_DOT := 0.45
const BRAKE_SPEED_THRESHOLD := 0.5
const REVERSE_ACCEL_FACTOR := 0.5
const THROTTLE_DEAD_ZONE := 0.1
const MIN_SPEED_FOR_FULL_TURN := 5.0
const DEFAULT_GRIP_MODIFIER_MULTIPLIER := 1.0
const DEFAULT_SPEED_CAP_FACTOR := 1.0
const SPEED_CAP_RESISTANCE := 0.5
const ACTIVE_INPUT_DRAG_FACTOR := 0.35
const DRIFT_EXIT_THRESHOLD_FACTOR := 0.75
const DRIFT_ENTRY_STEERING_THRESHOLD := 0.2
const OVERSPEED_BRAKE_RATIO := 0.65
const BODY_BASE_Y := -0.25
const MAX_VISUAL_STEER_ANGLE := deg_to_rad(30.0)
const WHEEL_STEER_SMOOTH_RATE := 15.0
const WHEEL_HARDPOINT_PATHS: Array[NodePath] = [
	^"WheelFrontLeft",
	^"WheelFrontRight",
	^"WheelRearLeft",
	^"WheelRearRight",
]
const FRONT_LEFT_WHEEL_INDEX := 0
const FRONT_RIGHT_WHEEL_INDEX := 1
const REAR_LEFT_WHEEL_INDEX := 2
const REAR_RIGHT_WHEEL_INDEX := 3

var steering_input: float = 0.0
var throttle_input: float = 0.0
var is_drifting: bool = false
var controls_enabled: bool = true
var is_grounded: bool = false
var grounded_wheel_count: int = 0
var ground_normal: Vector3 = Vector3.UP

var _surface_provider: Node = null
var _grip_modifier_multiplier: float = DEFAULT_GRIP_MODIFIER_MULTIPLIER
var _grip_modifier_time_remaining: float = 0.0
var _speed_cap_factor: float = DEFAULT_SPEED_CAP_FACTOR
var _pending_reset_transform: Transform3D = Transform3D.IDENTITY
var _has_pending_reset: bool = false
var _visual_steer_angle: float = 0.0
var _wheel_states: Array[WheelState] = []

@onready var _body_node: Node3D = get_node_or_null(^"Body")
@onready var _wheel_front_left: Node3D = get_node_or_null(^"Body/wheel-front-left")
@onready var _wheel_front_right: Node3D = get_node_or_null(^"Body/wheel-front-right")

signal drift_started
signal drift_ended


func _ready() -> void:
	if not stats:
		stats = load("res://car/default_stats.tres")
	_surface_provider = get_tree().get_first_node_in_group(SURFACE_PROVIDER_GROUP)
	_build_wheel_states()
	_ensure_body_visual_pose()
	_ensure_drift_feedback()
	_ensure_car_audio()


func _process(delta: float) -> void:
	_update_wheel_steering(delta)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_apply_pending_reset(state)

	if not stats:
		return

	_sample_inputs()

	var surface_profile: SurfaceProfile = _get_surface_profile(state.transform.origin)
	var car_up: Vector3 = state.transform.basis.y
	if car_up.length_squared() < 0.001:
		car_up = Vector3.UP
	else:
		car_up = car_up.normalized()

	_update_wheel_support(state, car_up)

	var up_axis: Vector3 = ground_normal if is_grounded else Vector3.UP
	var forward: Vector3 = _get_planar_forward_from_basis_on_axis(state.transform.basis, up_axis)
	var right: Vector3 = forward.cross(up_axis)
	if right.length_squared() < 0.001:
		right = _get_planar_right_from_forward(forward)
	else:
		right = right.normalized()

	var planar_velocity: Vector3 = state.linear_velocity.slide(up_axis)
	var fwd_speed: float = planar_velocity.dot(forward)
	var lat_speed: float = planar_velocity.dot(right)
	var acceleration_multiplier: float = surface_profile.acceleration_multiplier if surface_profile else 1.0
	var max_speed_multiplier: float = surface_profile.max_speed_multiplier if surface_profile else 1.0
	var drift_boost_multiplier: float = surface_profile.drift_boost_multiplier if surface_profile else 1.0
	var turn_speed_multiplier: float = surface_profile.turn_speed_multiplier if surface_profile else 1.0
	var grip_multiplier: float = surface_profile.grip_multiplier if surface_profile else 1.0
	var drift_grip_multiplier: float = surface_profile.drift_grip_multiplier if surface_profile else 1.0
	var drift_threshold_multiplier: float = surface_profile.drift_threshold_multiplier if surface_profile else 1.0
	var linear_drag_multiplier: float = surface_profile.linear_drag_multiplier if surface_profile else 1.0
	var acceleration_force: float = stats.acceleration_force * acceleration_multiplier
	var max_speed: float = stats.max_speed * max_speed_multiplier * _speed_cap_factor
	var reverse_max_speed: float = stats.reverse_max_speed * max_speed_multiplier * _speed_cap_factor
	var drift_threshold: float = stats.drift_threshold * drift_threshold_multiplier
	var grip: float = stats.grip * grip_multiplier * _grip_modifier_multiplier
	var drift_grip: float = stats.drift_grip * drift_grip_multiplier * _grip_modifier_multiplier
	var drift_boost_force: float = stats.drift_boost_force * drift_boost_multiplier
	var linear_drag: float = stats.linear_drag * linear_drag_multiplier
	var turn_speed: float = stats.turn_speed * turn_speed_multiplier
	var has_drive_contact: bool = grounded_wheel_count > 0

	var total_force: Vector3 = Vector3.ZERO

	if has_drive_contact:
		if throttle_input > 0.0 and fwd_speed < max_speed:
			total_force += forward * acceleration_force * throttle_input
		elif throttle_input < 0.0:
			if fwd_speed > BRAKE_SPEED_THRESHOLD:
				total_force += forward * stats.brake_force * throttle_input
			elif fwd_speed > -reverse_max_speed:
				total_force += forward * acceleration_force * REVERSE_ACCEL_FACTOR * throttle_input

	if has_drive_contact and fwd_speed > max_speed:
		total_force += -forward * stats.brake_force * OVERSPEED_BRAKE_RATIO
	if has_drive_contact and _speed_cap_factor < DEFAULT_SPEED_CAP_FACTOR and fwd_speed > max_speed:
		total_force += -forward * stats.brake_force * SPEED_CAP_RESISTANCE

	var was_drifting: bool = is_drifting
	var drift_enter_threshold: float = drift_threshold
	var drift_exit_threshold: float = drift_threshold * DRIFT_EXIT_THRESHOLD_FACTOR
	var lateral_speed_for_drift: float = absf(lat_speed)
	var can_drift: bool = grounded_wheel_count >= 2
	var has_drift_entry_speed: bool = can_drift and fwd_speed > stats.drift_min_speed
	var has_drift_exit_speed: bool = can_drift and fwd_speed > maxf(stats.drift_min_speed * DRIFT_EXIT_THRESHOLD_FACTOR, BRAKE_SPEED_THRESHOLD)
	var has_drift_intent: bool = absf(steering_input) >= DRIFT_ENTRY_STEERING_THRESHOLD
	if was_drifting:
		is_drifting = can_drift and lateral_speed_for_drift >= drift_exit_threshold and has_drift_exit_speed
	else:
		is_drifting = can_drift and lateral_speed_for_drift >= drift_enter_threshold and has_drift_entry_speed and has_drift_intent

	if is_drifting and not was_drifting:
		drift_started.emit()
	elif not is_drifting and was_drifting:
		drift_ended.emit()

	var current_grip: float = drift_grip if is_drifting else grip
	if has_drive_contact:
		total_force += -right * lat_speed * current_grip

	if has_drive_contact and is_drifting and fwd_speed < max_speed:
		var drift_speed_room: float = maxf(max_speed - fwd_speed, 0.0)
		var drift_boost_scale: float = clampf(drift_speed_room / maxf(max_speed, 0.001), 0.0, 1.0)
		total_force += forward * drift_boost_force * drift_boost_scale

	if has_drive_contact:
		var drag_factor: float = ACTIVE_INPUT_DRAG_FACTOR if absf(throttle_input) >= THROTTLE_DEAD_ZONE else 1.0
		total_force += -planar_velocity * linear_drag * drag_factor

	state.apply_central_force(total_force)

	var speed_factor: float = clampf(absf(fwd_speed) / MIN_SPEED_FOR_FULL_TURN, 0.0, 1.0)
	var steer: float = steering_input * turn_speed * speed_factor
	if fwd_speed < -1.0:
		steer *= -1.0
	if has_drive_contact:
		state.angular_velocity = _replace_angular_velocity_component(state.angular_velocity, up_axis, steer)
	else:
		state.angular_velocity = _replace_angular_velocity_component(
			state.angular_velocity,
			Vector3.UP,
			steer * stats.air_steer_factor
		)

	_tick_grip_modifier(state.step)


func reset_to_transform(spawn_transform: Transform3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = spawn_transform
	sleeping = false
	_pending_reset_transform = spawn_transform
	_has_pending_reset = true
	_clear_grip_modifier()
	clear_speed_cap()

	if is_drifting:
		is_drifting = false
		drift_ended.emit()

	steering_input = 0.0
	throttle_input = 0.0
	is_grounded = false
	grounded_wheel_count = 0
	ground_normal = Vector3.UP
	for wheel_state in _wheel_states:
		_reset_wheel_state(wheel_state)

	_visual_steer_angle = 0.0
	if _wheel_front_left != null:
		_wheel_front_left.rotation.y = 0.0
	if _wheel_front_right != null:
		_wheel_front_right.rotation.y = 0.0
	_ensure_body_visual_pose()


func set_controls_enabled(is_enabled: bool) -> void:
	controls_enabled = is_enabled
	if not controls_enabled:
		steering_input = 0.0
		throttle_input = 0.0


func set_frozen(should_freeze: bool) -> void:
	if should_freeze:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = should_freeze


func apply_forward_boost(boost_speed: float) -> void:
	if boost_speed <= 0.0:
		return

	var up_axis: Vector3 = _get_support_up_axis()
	var forward: Vector3 = _get_drive_forward_vector(up_axis)
	var current_velocity: Vector3 = linear_velocity
	var planar_velocity: Vector3 = current_velocity.slide(up_axis)
	var vertical_velocity: Vector3 = current_velocity - planar_velocity
	var current_forward_speed: float = planar_velocity.dot(forward)
	var lateral_velocity: Vector3 = planar_velocity - forward * current_forward_speed
	var boosted_forward_speed: float = current_forward_speed + boost_speed
	var max_boosted_speed: float = boosted_forward_speed
	var minimum_forward_speed: float = -INF

	if stats:
		max_boosted_speed = maxf(stats.max_speed + boost_speed, boost_speed)
		minimum_forward_speed = -stats.reverse_max_speed

	boosted_forward_speed = clampf(boosted_forward_speed, minimum_forward_speed, max_boosted_speed)
	linear_velocity = lateral_velocity + forward * boosted_forward_speed + vertical_velocity
	sleeping = false


func apply_grip_penalty(multiplier: float, duration: float) -> void:
	var safe_multiplier: float = clampf(multiplier, 0.0, DEFAULT_GRIP_MODIFIER_MULTIPLIER)
	var safe_duration: float = maxf(duration, 0.0)
	if safe_duration <= 0.0 or safe_multiplier >= DEFAULT_GRIP_MODIFIER_MULTIPLIER:
		_clear_grip_modifier()
		return

	_apply_grip_modifier(safe_multiplier, safe_duration)


func apply_grip_bonus(multiplier: float, duration: float) -> void:
	var safe_multiplier: float = maxf(multiplier, DEFAULT_GRIP_MODIFIER_MULTIPLIER)
	var safe_duration: float = maxf(duration, 0.0)
	if safe_duration <= 0.0 or is_equal_approx(safe_multiplier, DEFAULT_GRIP_MODIFIER_MULTIPLIER):
		_clear_grip_modifier()
		return

	_apply_grip_modifier(safe_multiplier, safe_duration)


func set_speed_cap(factor: float) -> void:
	_speed_cap_factor = clampf(factor, 0.0, 1.0)


func clear_speed_cap() -> void:
	_speed_cap_factor = DEFAULT_SPEED_CAP_FACTOR


func clear_temporary_handling_modifiers() -> void:
	_clear_grip_modifier()
	clear_speed_cap()


func apply_planar_velocity_delta(delta_velocity: Vector3) -> void:
	var planar_delta: Vector3 = delta_velocity.slide(_get_support_up_axis())
	apply_central_impulse(planar_delta * mass)
	sleeping = false


func _update_wheel_steering(delta: float) -> void:
	if _wheel_front_left == null or _wheel_front_right == null:
		return
	var target_angle: float = steering_input * MAX_VISUAL_STEER_ANGLE
	var weight: float = clampf(delta * WHEEL_STEER_SMOOTH_RATE, 0.0, 1.0)
	_visual_steer_angle = lerpf(_visual_steer_angle, target_angle, weight)
	_wheel_front_left.rotation.y = _visual_steer_angle
	_wheel_front_right.rotation.y = _visual_steer_angle


func _update_wheel_support(state: PhysicsDirectBodyState3D, car_up: Vector3) -> void:
	grounded_wheel_count = 0
	is_grounded = false
	ground_normal = Vector3.UP
	if _wheel_states.is_empty():
		return

	var weighted_ground_normal: Vector3 = Vector3.ZERO
	var unweighted_ground_normal: Vector3 = Vector3.ZERO
	var total_support_force: float = 0.0
	for wheel_state in _wheel_states:
		_update_single_wheel_support(state, wheel_state, car_up)
		if not wheel_state.grounded:
			continue

		grounded_wheel_count += 1
		unweighted_ground_normal += wheel_state.normal
		if wheel_state.support_force > 0.0:
			weighted_ground_normal += wheel_state.normal * wheel_state.support_force
			total_support_force += wheel_state.support_force

	_apply_anti_roll(state, FRONT_LEFT_WHEEL_INDEX, FRONT_RIGHT_WHEEL_INDEX, car_up)
	_apply_anti_roll(state, REAR_LEFT_WHEEL_INDEX, REAR_RIGHT_WHEEL_INDEX, car_up)

	is_grounded = grounded_wheel_count > 0
	if total_support_force > 0.0:
		ground_normal = (weighted_ground_normal / total_support_force).normalized()
	elif grounded_wheel_count > 0:
		ground_normal = (unweighted_ground_normal / float(grounded_wheel_count)).normalized()


func _update_single_wheel_support(
	state: PhysicsDirectBodyState3D,
	wheel_state: WheelState,
	car_up: Vector3
) -> void:
	_reset_wheel_state(wheel_state)
	var ray_length: float = stats.wheel_radius + stats.suspension_max_length
	var world_origin: Vector3 = state.transform * wheel_state.local_position
	var world_target: Vector3 = world_origin - car_up * ray_length
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		world_origin,
		world_target,
		1 << (TRACK_SURFACE_COLLISION_LAYER - 1),
		[get_rid()]
	)
	query.collide_with_areas = false
	var result: Dictionary = state.get_space_state().intersect_ray(query)
	if result.is_empty():
		return

	var hit_normal: Vector3 = result.get("normal", Vector3.ZERO)
	if hit_normal.length_squared() < 0.001:
		return
	hit_normal = hit_normal.normalized()
	if hit_normal.dot(car_up) < GROUND_MIN_NORMAL_DOT:
		return

	var hit_position: Vector3 = result.get("position", world_target)
	var hit_distance: float = world_origin.distance_to(hit_position)
	var suspension_length: float = clampf(
		hit_distance - stats.wheel_radius,
		stats.suspension_min_length,
		stats.suspension_max_length
	)
	var spring_force: float = (stats.suspension_rest_length - suspension_length) * stats.suspension_stiffness
	var damper_force: float = -state.get_velocity_at_local_position(wheel_state.local_position).dot(car_up) * stats.suspension_damping
	var support_force: float = maxf(spring_force + damper_force, 0.0)
	var global_force_offset: Vector3 = state.transform.basis * wheel_state.local_position

	wheel_state.grounded = true
	wheel_state.normal = hit_normal
	wheel_state.suspension_length = suspension_length
	wheel_state.compression_ratio = _get_compression_ratio(suspension_length)
	wheel_state.support_force = support_force

	state.apply_force(car_up * support_force, global_force_offset)


func _apply_anti_roll(
	state: PhysicsDirectBodyState3D,
	left_wheel_index: int,
	right_wheel_index: int,
	car_up: Vector3
) -> void:
	if left_wheel_index >= _wheel_states.size() or right_wheel_index >= _wheel_states.size():
		return

	var left_wheel: WheelState = _wheel_states[left_wheel_index]
	var right_wheel: WheelState = _wheel_states[right_wheel_index]
	if not left_wheel.grounded or not right_wheel.grounded:
		return

	var roll_delta: float = left_wheel.compression_ratio - right_wheel.compression_ratio
	if is_zero_approx(roll_delta):
		return

	var roll_force: float = roll_delta * stats.anti_roll_stiffness
	var left_global_force_offset: Vector3 = state.transform.basis * left_wheel.local_position
	var right_global_force_offset: Vector3 = state.transform.basis * right_wheel.local_position
	state.apply_force(car_up * roll_force, left_global_force_offset)
	state.apply_force(-car_up * roll_force, right_global_force_offset)


func _build_wheel_states() -> void:
	_wheel_states.clear()
	for wheel_path in WHEEL_HARDPOINT_PATHS:
		var hardpoint: Marker3D = get_node_or_null(wheel_path) as Marker3D
		if hardpoint == null:
			push_warning("Car could not find wheel hardpoint %s." % wheel_path)
			continue
		var wheel_state: WheelState = WheelState.new(hardpoint)
		_reset_wheel_state(wheel_state)
		_wheel_states.append(wheel_state)


func _reset_wheel_state(wheel_state: WheelState) -> void:
	wheel_state.grounded = false
	wheel_state.suspension_length = stats.suspension_rest_length if stats else 0.0
	wheel_state.compression_ratio = 0.0
	wheel_state.support_force = 0.0
	wheel_state.normal = Vector3.UP


func _get_compression_ratio(suspension_length: float) -> float:
	if stats == null or is_equal_approx(stats.suspension_max_length, stats.suspension_min_length):
		return 0.0
	return clampf(
		1.0 - inverse_lerp(stats.suspension_min_length, stats.suspension_max_length, suspension_length),
		0.0,
		1.0
	)


func _ensure_body_visual_pose() -> void:
	if _body_node == null:
		return
	var body_position: Vector3 = _body_node.position
	body_position.y = BODY_BASE_Y
	_body_node.position = body_position


func _get_surface_profile(world_position: Vector3) -> SurfaceProfile:
	if not is_instance_valid(_surface_provider):
		_surface_provider = get_tree().get_first_node_in_group(SURFACE_PROVIDER_GROUP)

	if _surface_provider and _surface_provider.has_method("get_surface_profile_at_position"):
		return _surface_provider.call("get_surface_profile_at_position", world_position) as SurfaceProfile

	return null


func _ensure_drift_feedback() -> void:
	var drift_feedback: DriftFeedback = get_node_or_null(DRIFT_FEEDBACK_NODE) as DriftFeedback
	if drift_feedback:
		drift_feedback.bind_car(self)
		return

	var new_drift_feedback: DriftFeedback = DriftFeedback.new()
	new_drift_feedback.name = DRIFT_FEEDBACK_NODE
	add_child(new_drift_feedback)
	new_drift_feedback.bind_car(self)


func _ensure_car_audio() -> void:
	var car_audio: CarAudio = get_node_or_null(CAR_AUDIO_NODE) as CarAudio
	if car_audio:
		car_audio.bind_car(self)
		return

	var new_car_audio: CarAudio = CarAudio.new()
	new_car_audio.name = CAR_AUDIO_NODE
	add_child(new_car_audio)
	new_car_audio.bind_car(self)


func _get_flat_forward_vector() -> Vector3:
	return _get_drive_forward_vector(_get_support_up_axis())


func _get_support_up_axis() -> Vector3:
	return ground_normal if is_grounded else Vector3.UP


func _get_drive_forward_vector(up_axis: Vector3) -> Vector3:
	return _get_planar_forward_from_basis_on_axis(global_basis, up_axis)


func _get_planar_forward_from_basis_on_axis(basis: Basis, up_axis: Vector3) -> Vector3:
	var forward: Vector3 = -basis.z
	forward = forward.slide(up_axis)
	if forward.length_squared() < 0.001:
		return Vector3.FORWARD
	return forward.normalized()


func _get_planar_right_from_forward(forward: Vector3) -> Vector3:
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)
	if right.length_squared() < 0.001:
		return Vector3.RIGHT
	return right.normalized()


func _replace_angular_velocity_component(current: Vector3, axis: Vector3, target_speed: float) -> Vector3:
	var normalized_axis: Vector3 = axis.normalized()
	var axis_component: Vector3 = normalized_axis * current.dot(normalized_axis)
	return current - axis_component + normalized_axis * target_speed


func _sample_inputs() -> void:
	if not controls_enabled:
		steering_input = 0.0
		throttle_input = 0.0
		return

	steering_input = Input.get_axis("steer_right", "steer_left")
	throttle_input = Input.get_axis("brake", "throttle")


func _apply_pending_reset(state: PhysicsDirectBodyState3D) -> void:
	if not _has_pending_reset:
		return

	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.transform = _pending_reset_transform
	_has_pending_reset = false


func _tick_grip_modifier(delta: float) -> void:
	if _grip_modifier_time_remaining <= 0.0:
		return

	_grip_modifier_time_remaining = maxf(_grip_modifier_time_remaining - delta, 0.0)
	if is_zero_approx(_grip_modifier_time_remaining):
		_clear_grip_modifier()


func _apply_grip_modifier(multiplier: float, duration: float) -> void:
	_grip_modifier_multiplier = multiplier
	_grip_modifier_time_remaining = duration


func _clear_grip_modifier() -> void:
	_grip_modifier_multiplier = DEFAULT_GRIP_MODIFIER_MULTIPLIER
	_grip_modifier_time_remaining = 0.0
