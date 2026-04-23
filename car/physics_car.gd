class_name PhysicsCar
extends Car

## Integrator-based arcade controller: the proxy `RigidBody3D` receives
## per-tick forces from `_integrate_proxy_forces`, heading is tracked as an
## explicit yaw vector (`_heading_forward`), and `CarStats` drives all the
## knobs — max speed, grip, drift thresholds, air steering, ground stick.
## Lifted from the pre-Kenney controller on branch `main`; trimmed to rely
## on `Car` base for signals, public state, and common helpers.

const SURFACE_PROVIDER_GROUP := &"surface_provider"
const CAR_AUDIO_NODE := "CarAudio"
## Body Y offset baked into the old `physics_car.tscn` transform; kept here
## so `Car._spawn_selected_body` can apply it on top of each `CarOption`'s
## intrinsic body transform.
const BODY_BASE_Y_OFFSET := -0.1
## Car root rests at world Y=-0.15 (proxy_center_height=0.4 vs ProxyCollision
## half-height 0.25), so the sedan-tuned smoke Y offset of -0.18 would emit
## 33cm below ground and get occluded. Shift up by the Car-root offset so the
## emitter world-Y matches SphereCar's.
const DRIFT_SMOKE_Y_OFFSET := -0.03
const DRIFT_SMOKE_LEFT_OFFSET := Vector3(-0.85, DRIFT_SMOKE_Y_OFFSET, 1.35)
const DRIFT_SMOKE_RIGHT_OFFSET := Vector3(0.85, DRIFT_SMOKE_Y_OFFSET, 1.35)
const BRAKE_SPEED_THRESHOLD := 0.5
const THROTTLE_DEAD_ZONE := 0.1
const DRIFT_ENTRY_STEERING_THRESHOLD := 0.28
const DRIFT_EXIT_STEERING_THRESHOLD := 0.16
const DRIFT_EXIT_THRESHOLD_FACTOR := 0.75
const DRIFT_INTENT_SPEED_FACTOR := 0.45
const DEFAULT_GRIP_MODIFIER_MULTIPLIER := 1.0
const DEFAULT_SPEED_CAP_FACTOR := 1.0
const DEFAULT_SPEED_CAP_SOURCE := &"default"
const SPEED_CAP_RESISTANCE := 0.5
const ACTIVE_INPUT_DRAG_FACTOR := 0.35
const OVERSPEED_BRAKE_RATIO := 0.65
const LOW_SPEED_TURN_SCALE := 0.22
const GROUND_MIN_NORMAL_DOT := 0.45
const GROUND_CONTACT_GRACE_DURATION := 0.06
const GROUND_CONTACT_GRACE_RISE_LIMIT := 1.5
const GROUND_STICK_VERTICAL_LIMIT := 2.0
const GROUND_PROBE_COLLISION_MASK := 1 << 2
const HEADING_PASSIVE_ALIGN_STEER_THRESHOLD := 0.2
const HEADING_DRIFT_ALIGN_STEER_THRESHOLD := 0.35
const HEADING_DRIFT_ALIGN_DOT_THRESHOLD := 0.35
const HEADING_RECOVERY_MIN_SPEED_FACTOR := 0.35
# Dot of `_heading_forward` against planar motion direction. -0.2 means motion
# opposes heading by more than ~101°, i.e. the car is clearly reversing.
const HEADING_REVERSE_ALIGN_DOT_THRESHOLD := -0.2
const LANDING_HEADING_RECOVERY_RATE := 10.0
const REVERSE_HEADING_RECOVERY_RATE := 3.5
const PASSIVE_HEADING_RECOVERY_RATE := 2.5
const DRIFT_HEADING_RECOVERY_RATE := 1.2
const REVERSE_LANDING_HEADING_SUPPRESS_DURATION := 0.12
const REVERSE_INTENT_RETENTION_DURATION := 0.5
const DEFAULT_PROXY_CENTER_HEIGHT := 0.4
const DEFAULT_PROXY_RADIUS := 0.65

var _surface_provider: Node = null
var _grip_modifier_multiplier: float = DEFAULT_GRIP_MODIFIER_MULTIPLIER
var _grip_modifier_time_remaining: float = 0.0
var _speed_cap_factor: float = DEFAULT_SPEED_CAP_FACTOR
var _speed_cap_sources: Dictionary[StringName, float] = {}
var _pending_reset_transform: Transform3D = Transform3D.IDENTITY
var _has_pending_reset: bool = false
var _heading_forward: Vector3 = Vector3.FORWARD
var _heading_turn_speed: float = 0.0
var _heading_correction_suppression_remaining: float = 0.0
var _reverse_intent_remaining: float = 0.0
var _ground_contact_grace_remaining: float = 0.0
var _ground_contact_grace_active: bool = false
var _had_full_ground_support_last_frame: bool = false
var _last_ground_normal: Vector3 = Vector3.UP
# 0.0 = sliding (use `drift_grip`), 1.0 = fully gripped (use `grip`). Snaps to
# 0.0 on drift entry and ramps back to 1.0 over `stats.drift_grip_recovery_duration`
# on exit so lateral velocity is redirected gradually instead of in a one-tick
# snap that reads as a spin-out.
var _drift_grip_blend: float = 0.1

@onready var _proxy_collision: CollisionShape3D = get_node_or_null(^"PhysicsProxy/ProxyCollision") as CollisionShape3D


func _ready() -> void:
	super._ready()
	# `_sync_root_from_proxy` writes `global_transform` from `_process`, which
	# would double-interpolate against Godot's physics interpolation and cause
	# jitter (see AGENTS.md "Self-smoothing follow nodes opt OUT"). The proxy
	# is `top_level = true`, so we read its already-interpolated position each
	# render frame and mirror it onto the Car root directly.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_surface_provider = get_tree().get_first_node_in_group(SURFACE_PROVIDER_GROUP)
	_capture_heading_from_basis(global_basis)
	_configure_collision_shapes_from_stats()
	_configure_ground_probe()
	if _physics_proxy != null:
		_physics_proxy.freeze = _is_frozen
	_teleport_proxy_to_root_transform(global_transform)
	_ensure_car_audio()


func _get_body_base_y_offset() -> float:
	return BODY_BASE_Y_OFFSET


func _process(delta: float) -> void:
	if not _has_pending_reset:
		_sync_root_from_proxy()
	if _visual_pose != null:
		_visual_pose.tick(delta)


func _integrate_proxy_forces(state: PhysicsDirectBodyState3D) -> void:
	_apply_pending_reset(state)

	if stats == null:
		return

	_heading_correction_suppression_remaining = maxf(_heading_correction_suppression_remaining - state.step, 0.0)

	_sample_inputs()
	_update_ground_probe(state.linear_velocity, state.step)

	# Read from `state.transform.origin` instead of `global_position` so we
	# don't depend on a start-of-tick root sync. The tail-of-tick sync after
	# `_advance_heading` is the one external readers see.
	var surface_profile: SurfaceProfile = _get_surface_profile(state.transform.origin)
	var acceleration_multiplier: float = surface_profile.acceleration_multiplier if surface_profile else 1.0
	var max_speed_multiplier: float = surface_profile.max_speed_multiplier if surface_profile else 1.0
	var drift_boost_multiplier: float = surface_profile.drift_boost_multiplier if surface_profile else 1.0
	var turn_speed_multiplier: float = surface_profile.turn_speed_multiplier if surface_profile else 1.0
	var grip_multiplier: float = surface_profile.grip_multiplier if surface_profile else 1.0
	var drift_grip_multiplier: float = surface_profile.drift_grip_multiplier if surface_profile else 1.0
	var drift_threshold_multiplier: float = surface_profile.drift_threshold_multiplier if surface_profile else 1.0
	var linear_drag_multiplier: float = surface_profile.linear_drag_multiplier if surface_profile else 1.0

	var drive_up: Vector3 = get_support_up_axis()
	var forward: Vector3 = get_drive_forward_vector(drive_up)
	var right: Vector3 = _get_right_from_forward(forward, drive_up)
	var planar_velocity: Vector3 = state.linear_velocity.slide(drive_up)
	var forward_speed: float = planar_velocity.dot(forward)
	var lateral_speed: float = planar_velocity.dot(right)
	var acceleration_force: float = stats.acceleration_force * acceleration_multiplier
	var reverse_acceleration_force: float = acceleration_force * stats.reverse_acceleration_factor
	var max_speed: float = stats.max_speed * max_speed_multiplier * _speed_cap_factor
	var reverse_max_speed: float = stats.reverse_max_speed * max_speed_multiplier * _speed_cap_factor
	var drift_threshold: float = stats.drift_threshold * drift_threshold_multiplier
	var grip: float = stats.grip * grip_multiplier * _grip_modifier_multiplier
	var drift_grip: float = stats.drift_grip * drift_grip_multiplier * _grip_modifier_multiplier
	var drift_boost_force: float = stats.drift_boost_force * drift_boost_multiplier
	var linear_drag: float = stats.linear_drag * linear_drag_multiplier
	var turn_speed: float = stats.turn_speed * turn_speed_multiplier
	var total_force: Vector3 = Vector3.ZERO
	var has_ground_support: bool = has_full_ground_support()
	var just_landed: bool = has_ground_support and not _had_full_ground_support_last_frame

	_update_drift_state(forward_speed, lateral_speed, drift_threshold, has_ground_support)

	if has_ground_support:
		if throttle_input > THROTTLE_DEAD_ZONE and forward_speed < max_speed:
			var uphill_drive_bonus: float = 1.0 + (maxf(forward.y, 0.0) * stats.uphill_acceleration_bonus)
			total_force += forward * acceleration_force * throttle_input * uphill_drive_bonus
		elif throttle_input < -THROTTLE_DEAD_ZONE:
			if forward_speed > BRAKE_SPEED_THRESHOLD:
				total_force += forward * stats.brake_force * throttle_input
			elif forward_speed > -reverse_max_speed:
				total_force += forward * reverse_acceleration_force * throttle_input

	if has_ground_support and forward_speed > max_speed:
		total_force += -forward * stats.brake_force * OVERSPEED_BRAKE_RATIO
	if has_ground_support and _speed_cap_factor < DEFAULT_SPEED_CAP_FACTOR and forward_speed > max_speed:
		total_force += -forward * stats.brake_force * SPEED_CAP_RESISTANCE

	var current_grip: float = _advance_drift_grip_blend(grip, drift_grip, state.step)
	if has_ground_support:
		total_force += -right * lateral_speed * current_grip
		if state.linear_velocity.dot(drive_up) <= GROUND_STICK_VERTICAL_LIMIT:
			total_force += -drive_up * stats.ground_stick_force

		var drag_factor: float = ACTIVE_INPUT_DRAG_FACTOR if absf(throttle_input) >= THROTTLE_DEAD_ZONE else 1.0
		total_force += -planar_velocity * linear_drag * drag_factor

		if is_drifting and forward_speed < max_speed:
			var drift_speed_room: float = maxf(max_speed - forward_speed, 0.0)
			var drift_boost_scale: float = clampf(drift_speed_room / maxf(max_speed, 0.001), 0.0, 1.0)
			total_force += forward * drift_boost_force * drift_boost_scale
	else:
		total_force += -planar_velocity * stats.air_drag

	state.apply_central_force(total_force)

	_reconcile_heading_with_velocity(planar_velocity, drive_up, state.step, just_landed)
	forward = get_drive_forward_vector(drive_up)
	right = _get_right_from_forward(forward, drive_up)
	planar_velocity = state.linear_velocity.slide(drive_up)
	forward_speed = planar_velocity.dot(forward)
	has_ground_support = has_full_ground_support()
	var target_yaw_speed: float = _get_target_yaw_speed(forward_speed, turn_speed, has_ground_support)
	var steering_response: float = stats.steering_response if has_ground_support else stats.air_steering_response
	_heading_turn_speed = move_toward(_heading_turn_speed, target_yaw_speed, steering_response * state.step)
	_advance_heading(_heading_turn_speed * state.step)

	if stats.proxy_angular_damp > 0.0:
		state.angular_velocity = state.angular_velocity.move_toward(Vector3.ZERO, stats.proxy_angular_damp * state.step)

	_tick_grip_modifier(state.step)
	_had_full_ground_support_last_frame = has_ground_support
	# Heading just advanced above; re-sync the root so external readers of
	# `global_basis` see the current heading within this tick.
	_sync_root_from_proxy_origin(state.transform.origin)


func reset_to_transform(spawn_transform: Transform3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = spawn_transform
	_pending_reset_transform = spawn_transform
	_has_pending_reset = true
	_clear_grip_modifier()
	_speed_cap_sources.clear()
	clear_speed_cap()
	_set_drifting(false)

	steering_input = 0.0
	throttle_input = 0.0
	is_grounded = false
	ground_normal = Vector3.UP
	_heading_turn_speed = 0.0
	_heading_correction_suppression_remaining = 0.0
	_reverse_intent_remaining = 0.0
	_ground_contact_grace_remaining = 0.0
	_ground_contact_grace_active = false
	_had_full_ground_support_last_frame = false
	_last_ground_normal = Vector3.UP
	_drift_grip_blend = 1.0
	_capture_heading_from_basis(spawn_transform.basis)

	if _physics_proxy != null:
		_teleport_proxy_to_root_transform(spawn_transform)
		_physics_proxy.sleeping = false
		# Proxy is `top_level = true`, so Car's reset_physics_interpolation
		# below does not cascade to it. Without this call the proxy's visual
		# position streaks from its pre-teleport tick state for one frame.
		_physics_proxy.reset_physics_interpolation()

	# Without this, physics interpolation would render the car swooping from
	# its previous transform to `spawn_transform` over one physics tick.
	reset_physics_interpolation()

	if _visual_pose != null:
		_visual_pose.reset_pose()


func set_controls_enabled(is_enabled: bool) -> void:
	super.set_controls_enabled(is_enabled)
	if not controls_enabled:
		_reverse_intent_remaining = 0.0


func set_frozen(should_freeze: bool) -> void:
	super.set_frozen(should_freeze)
	if should_freeze:
		_heading_turn_speed = 0.0
		_reverse_intent_remaining = 0.0
		_ground_contact_grace_remaining = 0.0
		_ground_contact_grace_active = false
		_had_full_ground_support_last_frame = false
		_drift_grip_blend = 1.0
		_set_drifting(false)


func apply_forward_boost(boost_speed: float) -> void:
	if boost_speed <= 0.0:
		return

	var up_axis: Vector3 = get_support_up_axis()
	var forward: Vector3 = get_drive_forward_vector(up_axis)
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
	if _physics_proxy != null:
		_physics_proxy.sleeping = false


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
	set_speed_cap_for_source(DEFAULT_SPEED_CAP_SOURCE, factor)


func clear_speed_cap() -> void:
	clear_speed_cap_for_source(DEFAULT_SPEED_CAP_SOURCE)


func set_speed_cap_for_source(source: StringName, factor: float) -> void:
	var source_key: StringName = _normalize_speed_cap_source(source)
	var safe_factor: float = clampf(factor, 0.0, DEFAULT_SPEED_CAP_FACTOR)
	if is_equal_approx(safe_factor, DEFAULT_SPEED_CAP_FACTOR):
		_speed_cap_sources.erase(source_key)
	else:
		_speed_cap_sources[source_key] = safe_factor
	_recompute_speed_cap_factor()


func clear_speed_cap_for_source(source: StringName) -> void:
	_speed_cap_sources.erase(_normalize_speed_cap_source(source))
	_recompute_speed_cap_factor()


func clear_temporary_handling_modifiers() -> void:
	_clear_grip_modifier()


func apply_planar_velocity_delta(delta_velocity: Vector3) -> void:
	if _is_frozen or _physics_proxy == null:
		return
	var planar_delta: Vector3 = delta_velocity.slide(get_support_up_axis())
	_physics_proxy.apply_central_impulse(planar_delta * _physics_proxy.mass)
	_physics_proxy.sleeping = false


func has_full_ground_support() -> bool:
	return is_grounded and not _ground_contact_grace_active


func get_support_up_axis() -> Vector3:
	return ground_normal if has_full_ground_support() else Vector3.UP


func get_drive_forward_vector(up_axis: Vector3) -> Vector3:
	return _get_planar_vector_on_axis(_heading_forward, up_axis)


func get_heading_forward() -> Vector3:
	return _heading_forward


func basis_from_forward_and_up(forward: Vector3, up_axis: Vector3) -> Basis:
	var safe_up: Vector3 = up_axis.normalized() if up_axis.length_squared() >= 0.001 else Vector3.UP
	var safe_forward: Vector3 = _get_planar_vector_on_axis(forward, safe_up)
	var right: Vector3 = _get_right_from_forward(safe_forward, safe_up)
	var corrected_forward: Vector3 = safe_up.cross(right)
	if corrected_forward.length_squared() < 0.001:
		corrected_forward = Vector3.FORWARD
	else:
		corrected_forward = corrected_forward.normalized()
	return Basis(right, safe_up, -corrected_forward).orthonormalized()


func _update_ground_probe(current_velocity: Vector3, delta: float) -> void:
	is_grounded = false
	ground_normal = Vector3.UP
	_ground_contact_grace_active = false
	if stats == null or _ground_probe == null:
		return

	_ground_probe.force_raycast_update()
	if not _ground_probe.is_colliding():
		_apply_ground_contact_grace(current_velocity, delta)
		return

	var hit_normal: Vector3 = _ground_probe.get_collision_normal()
	if hit_normal.length_squared() < 0.001:
		_apply_ground_contact_grace(current_velocity, delta)
		return

	hit_normal = hit_normal.normalized()
	var normal_dot_up: float = hit_normal.dot(Vector3.UP)
	if normal_dot_up < GROUND_MIN_NORMAL_DOT:
		_apply_ground_contact_grace(current_velocity, delta)
		return

	var hit_distance: float = _ground_probe.global_position.distance_to(_ground_probe.get_collision_point())
	if hit_distance > _get_grounded_hit_distance_limit(normal_dot_up):
		_apply_ground_contact_grace(current_velocity, delta)
		return

	is_grounded = true
	ground_normal = hit_normal
	_last_ground_normal = hit_normal
	_ground_contact_grace_remaining = GROUND_CONTACT_GRACE_DURATION


func _update_drift_state(
	forward_speed: float,
	lateral_speed: float,
	drift_threshold: float,
	has_ground_support: bool
) -> void:
	var lateral_speed_abs: float = absf(lateral_speed)
	var drift_intent_speed: float = maxf(forward_speed - stats.drift_min_speed, 0.0)
	var drift_metric: float = lateral_speed_abs + (absf(steering_input) * drift_intent_speed * DRIFT_INTENT_SPEED_FACTOR)
	var drift_exit_threshold: float = drift_threshold * DRIFT_EXIT_THRESHOLD_FACTOR
	var can_enter_drift: bool = (
		has_ground_support
		and forward_speed > stats.drift_min_speed
		and throttle_input > THROTTLE_DEAD_ZONE
		and absf(steering_input) >= DRIFT_ENTRY_STEERING_THRESHOLD
		and drift_metric >= drift_threshold
	)
	var can_hold_drift: bool = (
		has_ground_support
		and forward_speed > maxf(stats.drift_min_speed * DRIFT_EXIT_THRESHOLD_FACTOR, BRAKE_SPEED_THRESHOLD)
		and absf(steering_input) >= DRIFT_EXIT_STEERING_THRESHOLD
		and drift_metric >= drift_exit_threshold
	)

	_set_drifting(can_hold_drift if is_drifting else can_enter_drift)


func _set_drifting(should_drift: bool) -> void:
	if should_drift == is_drifting:
		return

	is_drifting = should_drift
	if is_drifting:
		drift_started.emit()
	else:
		drift_ended.emit()


func _advance_drift_grip_blend(grip: float, drift_grip: float, step: float) -> float:
	if is_drifting:
		_drift_grip_blend = 0.0
	else:
		var duration: float = maxf(stats.drift_grip_recovery_duration if stats else 0.0, 0.0001)
		_drift_grip_blend = minf(_drift_grip_blend + step / duration, 1.0)
	return lerpf(drift_grip, grip, _drift_grip_blend)


func _get_target_yaw_speed(forward_speed: float, turn_speed: float, has_ground_support: bool) -> float:
	if has_ground_support and absf(forward_speed) <= BRAKE_SPEED_THRESHOLD:
		return 0.0

	var speed_for_full_turn: float = stats.speed_for_full_turn if stats else 1.0
	var speed_factor: float = clampf(absf(forward_speed) / maxf(speed_for_full_turn, 0.001), 0.0, 1.0)
	var direction: float = 1.0
	if absf(forward_speed) > BRAKE_SPEED_THRESHOLD:
		direction = -1.0 if forward_speed < 0.0 else 1.0
	elif throttle_input < -THROTTLE_DEAD_ZONE:
		direction = -1.0

	var steer_scale: float = lerpf(LOW_SPEED_TURN_SCALE, 1.0, speed_factor)
	var drift_turn_multiplier: float = stats.drift_turn_multiplier if (stats and is_drifting) else 1.0
	var air_multiplier: float = 1.0 if has_ground_support else (stats.air_steer_factor if stats else 1.0)
	return steering_input * turn_speed * steer_scale * direction * drift_turn_multiplier * air_multiplier


func _reconcile_heading_with_velocity(
	planar_velocity: Vector3,
	up_axis: Vector3,
	delta: float,
	just_landed: bool
) -> void:
	var planar_speed: float = planar_velocity.length()
	if planar_speed <= BRAKE_SPEED_THRESHOLD:
		return

	var motion_forward: Vector3 = _get_planar_vector_on_axis(planar_velocity, up_axis)
	var alignment: float = clampf(_heading_forward.dot(motion_forward), -1.0, 1.0)

	# Gate the reverse-recovery preserve on a sustained-intent timer rather
	# than instantaneous throttle. Releasing the brake mid-reverse flips the
	# throttle check false in one tick, which without this timer lets the
	# aggressive REVERSE_HEADING_RECOVERY_RATE branch snap the heading 180°
	# to match the still-backward motion. The timer refreshes while the
	# player is actively reversing, holds (no decay) while motion is still
	# backward after release so drag alone does not have to outrun the
	# clock, and only decays once the car has escaped the reverse-aligned
	# motion band. That means REVERSE_HEADING_RECOVERY_RATE only fires for
	# unintended spins (external collisions), never for a player-driven
	# reverse release.
	var reversing_now: bool = (
		alignment <= HEADING_REVERSE_ALIGN_DOT_THRESHOLD
		and throttle_input <= -THROTTLE_DEAD_ZONE
	)
	if reversing_now:
		_reverse_intent_remaining = REVERSE_INTENT_RETENTION_DURATION
	elif alignment > HEADING_REVERSE_ALIGN_DOT_THRESHOLD:
		_reverse_intent_remaining = maxf(_reverse_intent_remaining - delta, 0.0)

	var correction_rate: float = 0.0
	var preserve_reverse_recovery: bool = (
		alignment <= HEADING_REVERSE_ALIGN_DOT_THRESHOLD
		and _reverse_intent_remaining > 0.0
	)
	var suppress_landing_correction: bool = (
		just_landed
		and (
			alignment <= HEADING_REVERSE_ALIGN_DOT_THRESHOLD
			or throttle_input <= -THROTTLE_DEAD_ZONE
			or absf(steering_input) >= HEADING_PASSIVE_ALIGN_STEER_THRESHOLD
			or is_drifting
		)
	)

	if preserve_reverse_recovery:
		return

	if suppress_landing_correction:
		_heading_correction_suppression_remaining = maxf(
			_heading_correction_suppression_remaining,
			REVERSE_LANDING_HEADING_SUPPRESS_DURATION
		)
		return

	if _heading_correction_suppression_remaining > 0.0:
		return

	if just_landed:
		correction_rate = LANDING_HEADING_RECOVERY_RATE
	elif (
		alignment < HEADING_REVERSE_ALIGN_DOT_THRESHOLD
		and not is_drifting
		and absf(steering_input) < HEADING_PASSIVE_ALIGN_STEER_THRESHOLD
	):
		correction_rate = REVERSE_HEADING_RECOVERY_RATE
	elif not is_drifting and absf(steering_input) < HEADING_PASSIVE_ALIGN_STEER_THRESHOLD:
		correction_rate = PASSIVE_HEADING_RECOVERY_RATE
	elif is_drifting and alignment < HEADING_DRIFT_ALIGN_DOT_THRESHOLD and absf(steering_input) < HEADING_DRIFT_ALIGN_STEER_THRESHOLD:
		correction_rate = DRIFT_HEADING_RECOVERY_RATE

	if correction_rate <= 0.0:
		return

	var speed_reference: float = stats.speed_for_full_turn if stats else 1.0
	var speed_factor: float = clampf(planar_speed / maxf(speed_reference, 0.001), HEADING_RECOVERY_MIN_SPEED_FACTOR, 1.0)
	var weight: float = clampf(delta * correction_rate * speed_factor, 0.0, 1.0)
	_heading_forward = _heading_forward.slerp(motion_forward, weight).normalized()


func _apply_ground_contact_grace(current_velocity: Vector3, delta: float) -> void:
	_ground_contact_grace_remaining = maxf(_ground_contact_grace_remaining - delta, 0.0)
	if _ground_contact_grace_remaining <= 0.0:
		return
	if current_velocity.y > GROUND_CONTACT_GRACE_RISE_LIMIT:
		return

	is_grounded = true
	ground_normal = _last_ground_normal
	_ground_contact_grace_active = true


func _configure_collision_shapes_from_stats() -> void:
	if _proxy_collision == null:
		return

	_proxy_collision.position = Vector3.ZERO
	var proxy_sphere: SphereShape3D = _proxy_collision.shape as SphereShape3D
	if proxy_sphere != null:
		proxy_sphere.radius = _get_proxy_radius()


func _configure_ground_probe() -> void:
	if _ground_probe == null:
		return

	_ground_probe.enabled = true
	_ground_probe.collide_with_areas = false
	_ground_probe.collide_with_bodies = true
	_ground_probe.collision_mask = GROUND_PROBE_COLLISION_MASK
	if stats != null:
		_ground_probe.position = Vector3(0.0, stats.ground_probe_start_height, 0.0)
		_ground_probe.target_position = Vector3(0.0, -_get_ground_probe_ray_length(), 0.0)


func _get_surface_profile(world_position: Vector3) -> SurfaceProfile:
	if not is_instance_valid(_surface_provider):
		_surface_provider = get_tree().get_first_node_in_group(SURFACE_PROVIDER_GROUP)

	if _surface_provider and _surface_provider.has_method("get_surface_profile_at_position"):
		return _surface_provider.call("get_surface_profile_at_position", world_position) as SurfaceProfile

	return null


func _configure_drift_feedback(feedback: DriftFeedback) -> void:
	feedback.left_rear_offset = DRIFT_SMOKE_LEFT_OFFSET
	feedback.right_rear_offset = DRIFT_SMOKE_RIGHT_OFFSET


func _ensure_car_audio() -> void:
	var car_audio: CarAudio = get_node_or_null(CAR_AUDIO_NODE) as CarAudio
	if car_audio:
		car_audio.bind_car(self)
		return

	var new_car_audio: CarAudio = CarAudio.new()
	new_car_audio.name = CAR_AUDIO_NODE
	add_child(new_car_audio)
	new_car_audio.bind_car(self)


func _get_ground_probe_ray_length() -> float:
	if stats == null:
		return 1.0
	return maxf(
		stats.ground_probe_length,
		_get_grounded_hit_distance_limit(GROUND_MIN_NORMAL_DOT)
	)


func _get_grounded_hit_distance_limit(normal_dot_up: float) -> float:
	var start_offset: float = maxf(stats.ground_probe_start_height - _get_proxy_center_height(), 0.0)
	var extra_clearance: float = maxf(stats.grounded_probe_distance - _get_proxy_radius(), 0.0)
	var safe_normal_dot: float = maxf(normal_dot_up, GROUND_MIN_NORMAL_DOT)
	return start_offset + (_get_proxy_radius() / safe_normal_dot) + extra_clearance


func _get_planar_vector_on_axis(vector: Vector3, up_axis: Vector3) -> Vector3:
	var planar_vector: Vector3 = vector.slide(up_axis)
	if planar_vector.length_squared() < 0.001:
		return Vector3.FORWARD
	return planar_vector.normalized()


func _get_right_from_forward(forward: Vector3, up_axis: Vector3) -> Vector3:
	var right: Vector3 = forward.cross(up_axis)
	if right.length_squared() < 0.001:
		return Vector3.RIGHT
	return right.normalized()


func _capture_heading_from_basis(source_basis: Basis) -> void:
	var flat_forward: Vector3 = -source_basis.z
	flat_forward.y = 0.0
	if flat_forward.length_squared() < 0.001:
		return
	_heading_forward = flat_forward.normalized()


func _advance_heading(yaw_delta: float) -> void:
	if absf(yaw_delta) <= 0.000001:
		return

	_heading_forward = _heading_forward.rotated(Vector3.UP, yaw_delta).normalized()


func _sample_inputs() -> void:
	if not controls_enabled or _is_frozen:
		steering_input = 0.0
		throttle_input = 0.0
		return

	# Signs: steering_input +left / -right (pressing A → +1, D → -1, and
	# +steering_input produces positive yaw around UP which rotates -Z forward
	# toward -X = car's left). throttle_input +throttle / -brake. Reverse is
	# driven by holding brake past zero forward_speed, so a negative
	# throttle_input can mean "braking" or "reversing" depending on motion.
	steering_input = Input.get_axis("steer_right", "steer_left")
	throttle_input = Input.get_axis("brake", "throttle")


func _apply_pending_reset(state: PhysicsDirectBodyState3D) -> void:
	if not _has_pending_reset:
		return

	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	state.transform = _get_proxy_transform_from_root(_pending_reset_transform)
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


func _normalize_speed_cap_source(source: StringName) -> StringName:
	return source if not String(source).is_empty() else DEFAULT_SPEED_CAP_SOURCE


func _recompute_speed_cap_factor() -> void:
	_speed_cap_factor = DEFAULT_SPEED_CAP_FACTOR
	for factor_value in _speed_cap_sources.values():
		_speed_cap_factor = minf(_speed_cap_factor, float(factor_value))


func _sync_root_from_proxy() -> void:
	if _physics_proxy == null:
		return
	_sync_root_from_proxy_origin(_physics_proxy.global_position)


## Root invariant: Car's basis is yaw-only around world UP. Visual lean
## (pitch/roll) is written onto the `VisualRoot` node by `CarVisualPose`,
## derived relative to this root basis, so any external consumer of
## `global_basis` sees a flat heading frame that does not wobble with terrain.
func _sync_root_from_proxy_origin(proxy_origin: Vector3) -> void:
	var root_transform: Transform3D = global_transform
	root_transform.origin = proxy_origin - Vector3.UP * _get_proxy_center_height()
	root_transform.basis = basis_from_forward_and_up(_heading_forward, Vector3.UP)
	global_transform = root_transform


func _teleport_proxy_to_root_transform(root_transform: Transform3D) -> void:
	if _physics_proxy == null:
		return
	_physics_proxy.global_transform = _get_proxy_transform_from_root(root_transform)
	_physics_proxy.linear_velocity = Vector3.ZERO
	_physics_proxy.angular_velocity = Vector3.ZERO


func _get_proxy_transform_from_root(root_transform: Transform3D) -> Transform3D:
	return Transform3D(Basis.IDENTITY, root_transform.origin + Vector3.UP * _get_proxy_center_height())


func _get_proxy_center_height() -> float:
	if stats == null:
		return DEFAULT_PROXY_CENTER_HEIGHT
	return stats.proxy_center_height


func _get_proxy_radius() -> float:
	if stats == null:
		return DEFAULT_PROXY_RADIUS
	return stats.proxy_radius
