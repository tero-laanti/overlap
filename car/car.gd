class_name Car
extends RigidBody3D

@export var stats: CarStats

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
	steering_input = Input.get_axis("steer_right", "steer_left")
	throttle_input = Input.get_axis("brake", "throttle")


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not stats:
		return

	var body_basis: Basis = state.transform.basis
	var forward := -body_basis.z
	var right := body_basis.x

	var vel := state.linear_velocity
	vel.y = 0.0
	var fwd_speed := vel.dot(forward)
	var lat_speed := vel.dot(right)

	var total_force := Vector3.ZERO

	# --- Throttle / Brake ---
	if throttle_input > 0.0 and fwd_speed < stats.max_speed:
		total_force += forward * stats.acceleration_force * throttle_input
	elif throttle_input < 0.0:
		if fwd_speed > BRAKE_SPEED_THRESHOLD:
			total_force += forward * stats.brake_force * throttle_input
		elif fwd_speed > -stats.reverse_max_speed:
			total_force += forward * stats.acceleration_force * REVERSE_ACCEL_FACTOR * throttle_input

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
	if absf(throttle_input) < THROTTLE_DEAD_ZONE:
		total_force += -vel * stats.linear_drag

	state.apply_central_force(total_force)

	# --- Steering: set angular velocity directly for snappy feel ---
	var speed_factor := clampf(absf(fwd_speed) / MIN_SPEED_FOR_FULL_TURN, 0.0, 1.0)
	var steer: float = steering_input * stats.turn_speed * speed_factor
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
