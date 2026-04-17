class_name GameCamera
extends Camera3D

const MIN_LOOK_DISTANCE := 0.5

@export var target_path: NodePath
@export var follow_distance := 10.0
@export var look_ahead := 12.0
@export var min_height := 12.0
@export var max_height := 22.0
@export var zoom_speed_ref := 25.0 ## Car speed at which max height is reached
@export var position_smoothing := 5.0
@export var rotation_smoothing := 3.0

var target: Node3D = null
var _smooth_look_target := Vector3.ZERO


func _ready() -> void:
	target = get_node_or_null(target_path)
	if target:
		snap_to_target()


func _process(delta: float) -> void:
	if not target:
		return

	var car_forward := _get_target_forward()

	# Dynamic height based on speed
	var speed: float = 0.0
	if target is Car:
		speed = (target as Car).linear_velocity.slide(Vector3.UP).length()
	elif target is RigidBody3D:
		speed = (target as RigidBody3D).linear_velocity.slide(Vector3.UP).length()
	var speed_pct := clampf(speed / zoom_speed_ref, 0.0, 1.0)
	var current_height := lerpf(min_height, max_height, speed_pct)

	# Camera sits behind and above the car
	var car_pos := target.global_position
	var cam_offset := -car_forward * follow_distance + Vector3.UP * current_height
	var target_pos := car_pos + cam_offset
	global_position = global_position.lerp(target_pos, _get_smoothing_weight(position_smoothing, delta))

	# Look ahead of the car (smoothed for gentle rotation)
	var look_target := car_pos + car_forward * look_ahead
	_smooth_look_target = _smooth_look_target.lerp(look_target, _get_smoothing_weight(rotation_smoothing, delta))
	_look_toward(_smooth_look_target, car_forward)


func snap_to_target() -> void:
	if not target:
		return

	var car_pos := target.global_position
	var car_forward := _get_target_forward()
	global_position = car_pos + (-car_forward * follow_distance) + Vector3.UP * min_height
	_smooth_look_target = car_pos + car_forward * look_ahead
	_look_toward(_smooth_look_target, car_forward)


func _get_target_forward() -> Vector3:
	var fwd := -target.global_basis.z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		return Vector3.FORWARD
	return fwd.normalized()


func _look_toward(look_target: Vector3, fallback_forward: Vector3) -> void:
	var safe_forward: Vector3 = fallback_forward
	if safe_forward.length_squared() < 0.001:
		safe_forward = Vector3.FORWARD
	else:
		safe_forward = safe_forward.normalized()

	var safe_target: Vector3 = look_target
	if global_position.distance_squared_to(safe_target) < MIN_LOOK_DISTANCE * MIN_LOOK_DISTANCE:
		safe_target = global_position + safe_forward * MIN_LOOK_DISTANCE

	look_at(safe_target, Vector3.UP)


func _get_smoothing_weight(smoothing: float, delta: float) -> float:
	if smoothing <= 0.0:
		return 1.0
	return 1.0 - exp(-smoothing * delta)
