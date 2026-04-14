extends Camera3D

@export var target_path: NodePath
@export var follow_distance := 8.0
@export var look_ahead := 5.0
@export var min_height := 12.0
@export var max_height := 22.0
@export var zoom_speed_ref := 25.0 ## Car speed at which max height is reached
@export var position_smoothing := 5.0
@export var rotation_smoothing := 3.0

var target: Node3D
var _smooth_look_target := Vector3.ZERO


func _ready() -> void:
	target = get_node_or_null(target_path)
	if target:
		_snap_to_target()
	print("Camera ready. Target: ", target, " Position: ", global_position, " Current: ", current)


func _process(delta: float) -> void:
	if not target:
		return

	var car_pos := target.global_position
	var car_forward := -target.global_basis.z
	car_forward.y = 0.0
	if car_forward.length_squared() < 0.001:
		car_forward = Vector3.FORWARD
	car_forward = car_forward.normalized()

	# Dynamic height based on speed
	var speed := 0.0
	if target is RigidBody3D:
		speed = target.linear_velocity.length()
	var speed_pct := clampf(speed / zoom_speed_ref, 0.0, 1.0)
	var current_height := lerpf(min_height, max_height, speed_pct)

	# Camera sits behind and above the car
	var cam_offset := -car_forward * follow_distance + Vector3.UP * current_height
	var target_pos := car_pos + cam_offset
	global_position = global_position.lerp(target_pos, position_smoothing * delta)

	# Look ahead of the car (smoothed for gentle rotation)
	var look_target := car_pos + car_forward * look_ahead
	_smooth_look_target = _smooth_look_target.lerp(look_target, rotation_smoothing * delta)
	look_at(_smooth_look_target, Vector3.UP)


func _snap_to_target() -> void:
	var car_pos := target.global_position
	var car_forward := -target.global_basis.z
	car_forward.y = 0.0
	if car_forward.length_squared() < 0.001:
		car_forward = Vector3.FORWARD
	car_forward = car_forward.normalized()

	global_position = car_pos + (-car_forward * follow_distance) + Vector3.UP * min_height
	_smooth_look_target = car_pos + car_forward * look_ahead
	look_at(_smooth_look_target, Vector3.UP)
