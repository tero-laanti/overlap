class_name Car
extends RigidBody3D

@export var stats: CarStats

const SURFACE_PROVIDER_GROUP := &"surface_provider"
const DRIFT_FEEDBACK_NODE := "DriftFeedback"
const CAR_AUDIO_NODE := "CarAudio"
## Minimum forward speed before braking force applies (below this, reverse kicks in).
const BRAKE_SPEED_THRESHOLD := 0.5
## Reverse acceleration is this fraction of forward acceleration.
const REVERSE_ACCEL_FACTOR := 0.5
## Throttle values below this are treated as "coasting" (no input).
const THROTTLE_DEAD_ZONE := 0.1
## Minimum forward speed to reach full turning rate.
const MIN_SPEED_FOR_FULL_TURN := 5.0
## Y position the car is locked to (ground plane).
const GROUND_Y := 0.25
const DEFAULT_GRIP_MODIFIER_MULTIPLIER := 1.0
const DEFAULT_SPEED_CAP_FACTOR := 1.0
## Fraction of brake_force applied when the car exceeds a speed cap.
const SPEED_CAP_RESISTANCE := 0.5
const ACTIVE_INPUT_DRAG_FACTOR := 0.35
const DRIFT_EXIT_THRESHOLD_FACTOR := 0.75
const DRIFT_ENTRY_STEERING_THRESHOLD := 0.2
const OVERSPEED_BRAKE_RATIO := 0.65

var steering_input: float = 0.0
var throttle_input: float = 0.0
var is_drifting: bool = false
var controls_enabled: bool = true
var _surface_provider: Node = null
var _grip_modifier_multiplier: float = DEFAULT_GRIP_MODIFIER_MULTIPLIER
var _grip_modifier_time_remaining: float = 0.0
var _speed_cap_factor: float = DEFAULT_SPEED_CAP_FACTOR
var _pending_reset_transform: Transform3D = Transform3D.IDENTITY
var _has_pending_reset: bool = false

signal drift_started
signal drift_ended


func _ready() -> void:
	if not stats:
		stats = load("res://car/default_stats.tres")
	_surface_provider = get_tree().get_first_node_in_group(SURFACE_PROVIDER_GROUP)
	_ensure_drift_feedback()
	_ensure_car_audio()


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


func set_controls_enabled(is_enabled: bool) -> void:
	controls_enabled = is_enabled
	if not controls_enabled:
		steering_input = 0.0
		throttle_input = 0.0


## Freezes or unfreezes the car's physics. Zeros velocity on freeze so the body
## doesn't resume drifting when it unfreezes. Used to hold the car still while
## the pit stop UI is up.
func set_frozen(should_freeze: bool) -> void:
	if should_freeze:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	freeze = should_freeze


func apply_forward_boost(boost_speed: float) -> void:
	if boost_speed <= 0.0:
		return

	var forward: Vector3 = _get_flat_forward_vector()

	var current_velocity: Vector3 = linear_velocity
	var vertical_velocity: float = current_velocity.y
	var planar_velocity: Vector3 = current_velocity
	planar_velocity.y = 0.0

	var current_forward_speed: float = planar_velocity.dot(forward)
	var lateral_velocity: Vector3 = planar_velocity - forward * current_forward_speed
	var boosted_forward_speed: float = current_forward_speed + boost_speed
	var max_boosted_speed: float = boosted_forward_speed
	var minimum_forward_speed: float = -INF

	if stats:
		max_boosted_speed = maxf(stats.max_speed + boost_speed, boost_speed)
		minimum_forward_speed = -stats.reverse_max_speed

	boosted_forward_speed = clampf(boosted_forward_speed, minimum_forward_speed, max_boosted_speed)
	linear_velocity = lateral_velocity + forward * boosted_forward_speed + Vector3.UP * vertical_velocity
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
	var planar_delta: Vector3 = delta_velocity
	planar_delta.y = 0.0
	linear_velocity += planar_delta
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_apply_pending_reset(state)

	if not stats:
		return

	_sample_inputs()

	var surface_profile: SurfaceProfile = _get_surface_profile(state.transform.origin)
	var body_basis: Basis = state.transform.basis
	var forward := -body_basis.z
	var right := body_basis.x

	var vel := state.linear_velocity
	vel.y = 0.0
	var fwd_speed := vel.dot(forward)
	var lat_speed := vel.dot(right)
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

	var total_force := Vector3.ZERO

	# --- Throttle / Brake ---
	if throttle_input > 0.0 and fwd_speed < max_speed:
		total_force += forward * acceleration_force * throttle_input
	elif throttle_input < 0.0:
		if fwd_speed > BRAKE_SPEED_THRESHOLD:
			total_force += forward * stats.brake_force * throttle_input
		elif fwd_speed > -reverse_max_speed:
			total_force += forward * acceleration_force * REVERSE_ACCEL_FACTOR * throttle_input

	# --- Speed cap resistance ---
	if fwd_speed > max_speed:
		total_force += -forward * stats.brake_force * OVERSPEED_BRAKE_RATIO
	if _speed_cap_factor < DEFAULT_SPEED_CAP_FACTOR and fwd_speed > max_speed:
		total_force += -forward * stats.brake_force * SPEED_CAP_RESISTANCE

	# --- Drift detection ---
	var was_drifting := is_drifting
	var drift_enter_threshold: float = drift_threshold
	var drift_exit_threshold: float = drift_threshold * DRIFT_EXIT_THRESHOLD_FACTOR
	var lateral_speed_for_drift: float = absf(lat_speed)
	var has_drift_entry_speed: bool = fwd_speed > stats.drift_min_speed
	var has_drift_exit_speed: bool = fwd_speed > maxf(stats.drift_min_speed * DRIFT_EXIT_THRESHOLD_FACTOR, BRAKE_SPEED_THRESHOLD)
	var has_drift_intent: bool = absf(steering_input) >= DRIFT_ENTRY_STEERING_THRESHOLD
	if was_drifting:
		is_drifting = lateral_speed_for_drift >= drift_exit_threshold and has_drift_exit_speed
	else:
		is_drifting = lateral_speed_for_drift >= drift_enter_threshold and has_drift_entry_speed and has_drift_intent

	if is_drifting and not was_drifting:
		drift_started.emit()
	elif not is_drifting and was_drifting:
		drift_ended.emit()

	# --- Grip (kill lateral velocity) ---
	var current_grip: float = drift_grip if is_drifting else grip
	total_force += -right * lat_speed * current_grip

	# --- Drift boost (the Big Lie: drifting preserves/adds speed) ---
	if is_drifting and fwd_speed < max_speed:
		var drift_speed_room: float = maxf(max_speed - fwd_speed, 0.0)
		var drift_boost_scale: float = clampf(drift_speed_room / maxf(max_speed, 0.001), 0.0, 1.0)
		total_force += forward * drift_boost_force * drift_boost_scale

	# --- Linear drag ---
	var drag_factor: float = ACTIVE_INPUT_DRAG_FACTOR if absf(throttle_input) >= THROTTLE_DEAD_ZONE else 1.0
	total_force += -vel * linear_drag * drag_factor

	state.apply_central_force(total_force)

	# --- Steering: set angular velocity directly for snappy feel ---
	var speed_factor := clampf(absf(fwd_speed) / MIN_SPEED_FOR_FULL_TURN, 0.0, 1.0)
	var steer: float = steering_input * turn_speed * speed_factor
	if fwd_speed < -1.0:
		steer *= -1.0
	state.angular_velocity = Vector3(0.0, steer, 0.0)

	# --- Constrain to ground plane ---
	state.linear_velocity.y = 0.0
	var xform := state.transform
	xform.origin.y = GROUND_Y
	var yaw := xform.basis.get_euler().y
	xform.basis = Basis.from_euler(Vector3(0.0, yaw, 0.0))
	state.transform = xform
	_tick_grip_modifier(state.step)


func _get_surface_profile(world_position: Vector3) -> SurfaceProfile:
	if not is_instance_valid(_surface_provider):
		_surface_provider = get_tree().get_first_node_in_group(SURFACE_PROVIDER_GROUP)

	if _surface_provider and _surface_provider.has_method("get_surface_profile_at_position"):
		return _surface_provider.call("get_surface_profile_at_position", world_position) as SurfaceProfile

	return null


func _ensure_drift_feedback() -> void:
	var drift_feedback := get_node_or_null(DRIFT_FEEDBACK_NODE) as DriftFeedback
	if drift_feedback:
		drift_feedback.bind_car(self)
		return

	var new_drift_feedback: DriftFeedback = DriftFeedback.new()
	new_drift_feedback.name = DRIFT_FEEDBACK_NODE
	add_child(new_drift_feedback)
	new_drift_feedback.bind_car(self)


func _ensure_car_audio() -> void:
	var car_audio := get_node_or_null(CAR_AUDIO_NODE) as CarAudio
	if car_audio:
		car_audio.bind_car(self)
		return

	var new_car_audio: CarAudio = CarAudio.new()
	new_car_audio.name = CAR_AUDIO_NODE
	add_child(new_car_audio)
	new_car_audio.bind_car(self)


func _get_flat_forward_vector() -> Vector3:
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return Vector3.FORWARD
	return forward.normalized()


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
