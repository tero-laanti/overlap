extends RigidBody3D

@export var stats: Resource ## CarStats resource

var steering_input := 0.0
var throttle_input := 0.0
var is_drifting := false

signal drift_started
signal drift_ended


func _ready() -> void:
	if not stats:
		stats = load("res://car/default_stats.tres")
	print("Car ready. Stats: ", stats, " Position: ", global_position)


func _process(_delta: float) -> void:
	steering_input = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		steering_input = 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		steering_input -= 1.0

	throttle_input = 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		throttle_input = 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		throttle_input -= 1.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not stats:
		return

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	var vel := state.linear_velocity
	vel.y = 0.0
	var fwd_speed := vel.dot(forward)
	var lat_speed := vel.dot(right)

	var total_force := Vector3.ZERO

	# --- Throttle / Brake ---
	if throttle_input > 0.0 and fwd_speed < stats.max_speed:
		total_force += forward * stats.acceleration_force * throttle_input
	elif throttle_input < 0.0:
		if fwd_speed > 0.5:
			total_force += forward * stats.brake_force * throttle_input
		elif fwd_speed > -stats.reverse_max_speed:
			total_force += forward * stats.acceleration_force * 0.5 * throttle_input

	# --- Drift detection ---
	var was_drifting := is_drifting
	is_drifting = absf(lat_speed) > stats.drift_threshold and absf(fwd_speed) > stats.drift_min_speed

	if is_drifting and not was_drifting:
		drift_started.emit()
	elif not is_drifting and was_drifting:
		drift_ended.emit()

	# --- Grip (kill lateral velocity) ---
	var current_grip: float = stats.drift_grip if is_drifting else stats.grip
	total_force += -right * lat_speed * current_grip

	# --- Drift boost (the Big Lie: drifting preserves/adds speed) ---
	if is_drifting:
		total_force += forward * stats.drift_boost_force

	# --- Linear drag when coasting ---
	if absf(throttle_input) < 0.1:
		total_force += -vel * stats.linear_drag

	state.apply_central_force(total_force)

	# --- Steering: set angular velocity directly for snappy feel ---
	var speed_factor := clampf(absf(fwd_speed) / 5.0, 0.0, 1.0)
	var steer: float = steering_input * stats.turn_speed * speed_factor
	if fwd_speed < -1.0:
		steer *= -1.0
	state.angular_velocity = Vector3(0.0, steer, 0.0)

	# --- Constrain to ground plane ---
	state.linear_velocity.y = 0.0
	var xform := state.transform
	xform.origin.y = 0.25
	var yaw := xform.basis.get_euler().y
	xform.basis = Basis.from_euler(Vector3(0.0, yaw, 0.0))
	state.transform = xform
