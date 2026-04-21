class_name CarVisualPose
extends Node3D

const VISUAL_ALIGN_SMOOTH_RATE := 10.0
const VISUAL_POSE_SMOOTH_RATE := 8.0
const VISUAL_DRIFT_ROLL_MULTIPLIER := 1.2
const VISUAL_PITCH_ACCEL_WEIGHT := 0.01
const VISUAL_PITCH_VERTICAL_WEIGHT := 0.02
const MAX_VISUAL_ROLL_ANGLE := deg_to_rad(10.0)
const MAX_VISUAL_PITCH_ANGLE := deg_to_rad(6.0)
const MAX_VISUAL_STEER_ANGLE := deg_to_rad(30.0)
const WHEEL_STEER_SMOOTH_RATE := 15.0
const VISUAL_IDLE_PLANAR_SPEED_EPSILON := 0.05
const VISUAL_IDLE_STEERING_EPSILON := 0.1
const VISUAL_IDLE_ANGLE_EPSILON := 0.002

const VISUAL_ROOT_PATH := ^"VisualRoot"
const BODY_NODE_NAME := &"Body"
## Kenney sedans put `wheel-front-*` directly under the GLB scene root, but
## kart GLBs nest them one level deeper (`kart-oopi/wheel-front-left`). A
## recursive name lookup handles both without per-model path config.
const WHEEL_FRONT_LEFT_NODE_NAME := &"wheel-front-left"
const WHEEL_FRONT_RIGHT_NODE_NAME := &"wheel-front-right"

var car: Car = null

var _visual_root: Node3D = null
var _wheel_front_left: Node3D = null
var _wheel_front_right: Node3D = null

var _visual_surface_up: Vector3 = Vector3.UP
var _visual_forward_speed: float = 0.0
var _visual_steer_angle: float = 0.0
var _visual_roll_angle: float = 0.0
var _visual_pitch_angle: float = 0.0
var _visual_root_base_origin: Vector3 = Vector3.ZERO
var _visual_root_base_rotation: Basis = Basis.IDENTITY
var _visual_root_base_scale: Vector3 = Vector3.ONE
var _rest_pose_cached: bool = false


func _ready() -> void:
	if car != null:
		bind_car(car)


func bind_car(car_owner: Car) -> void:
	car = car_owner
	if car == null:
		return
	_visual_root = car.get_node_or_null(VISUAL_ROOT_PATH) as Node3D
	_resolve_wheel_nodes()
	if not _rest_pose_cached:
		_cache_visual_rest_pose()
	_ensure_visual_root_pose()


## Re-resolves the wheel references after the body has been swapped. Car
## spawns its body dynamically from `CarOptions` on `_ready`, so the initial
## `bind_car` call may run before the body exists.
func refresh_body_references() -> void:
	if car == null:
		return
	_resolve_wheel_nodes()


func _resolve_wheel_nodes() -> void:
	_wheel_front_left = null
	_wheel_front_right = null
	if _visual_root == null:
		return
	var body: Node = _visual_root.get_node_or_null(NodePath(BODY_NODE_NAME))
	if body == null:
		return
	_wheel_front_left = _find_descendant_by_name(body, WHEEL_FRONT_LEFT_NODE_NAME) as Node3D
	_wheel_front_right = _find_descendant_by_name(body, WHEEL_FRONT_RIGHT_NODE_NAME) as Node3D


static func _find_descendant_by_name(root: Node, target_name: StringName) -> Node:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node != root and node.name == target_name:
			return node
		for child in node.get_children():
			stack.append(child)
	return null


func get_visual_root() -> Node3D:
	return _visual_root


func reset_pose() -> void:
	_visual_surface_up = Vector3.UP
	_visual_forward_speed = 0.0
	_visual_steer_angle = 0.0
	_visual_roll_angle = 0.0
	_visual_pitch_angle = 0.0
	if _wheel_front_left != null:
		_wheel_front_left.rotation.y = 0.0
	if _wheel_front_right != null:
		_wheel_front_right.rotation.y = 0.0
	_ensure_visual_root_pose()


## Driven externally from `Car._process` so the pose reads `global_basis`
## after `_sync_root_from_proxy` has written the current yaw-only frame.
func tick(delta: float) -> void:
	_update_visual_pose(delta)
	_update_wheel_steering(delta)


## Wheel-steering-only tick for controllers (like `SphereCar`) that drive
## body pose themselves and only need the front-wheel yaw animated.
func tick_wheels(delta: float) -> void:
	_update_wheel_steering(delta)


func _update_visual_pose(delta: float) -> void:
	if car == null or _visual_root == null:
		return

	var align_weight: float = clampf(delta * VISUAL_ALIGN_SMOOTH_RATE, 0.0, 1.0)
	if car.has_full_ground_support():
		var current_visual_up: Vector3 = _visual_surface_up.normalized() if _visual_surface_up.length_squared() >= 0.001 else Vector3.UP
		var target_ground_up: Vector3 = car.ground_normal.normalized() if car.ground_normal.length_squared() >= 0.001 else Vector3.UP
		_visual_surface_up = current_visual_up.slerp(target_ground_up, align_weight)
	elif _visual_surface_up.length_squared() < 0.001:
		_visual_surface_up = Vector3.UP
	_visual_surface_up = _visual_surface_up.normalized()

	var drive_up: Vector3 = car.get_support_up_axis()
	var forward: Vector3 = car.get_drive_forward_vector(drive_up)
	var car_velocity: Vector3 = car.linear_velocity
	var planar_velocity: Vector3 = car_velocity.slide(drive_up)
	var forward_speed: float = planar_velocity.dot(forward)
	var max_speed: float = car.stats.max_speed if car.stats else 1.0
	var speed_ratio: float = clampf(absf(forward_speed) / maxf(max_speed, 0.001), 0.0, 1.0)
	var forward_acceleration: float = (forward_speed - _visual_forward_speed) / maxf(delta, 0.001)
	_visual_forward_speed = forward_speed
	var roll_multiplier: float = VISUAL_DRIFT_ROLL_MULTIPLIER if car.is_drifting else 1.0
	var target_roll: float = -car.steering_input * MAX_VISUAL_ROLL_ANGLE * speed_ratio * roll_multiplier
	var target_pitch: float = clampf(
		(-forward_acceleration * VISUAL_PITCH_ACCEL_WEIGHT) - (car_velocity.y * VISUAL_PITCH_VERTICAL_WEIGHT),
		-MAX_VISUAL_PITCH_ANGLE,
		MAX_VISUAL_PITCH_ANGLE
	)

	# The Basis/Quaternion work below is the per-tick hot path. When the car
	# is grounded, parked, neutral-input, and already at its smoothed target
	# angles, skip it. The guard requires target-vs-current angle equality,
	# so mid-animation (e.g. pitch settling after a landing) still runs the
	# full smoothing pass. Grounding is part of the guard so an airborne
	# drop with near-zero planar velocity does not short-circuit.
	if (
		car.is_grounded
		and planar_velocity.length() < VISUAL_IDLE_PLANAR_SPEED_EPSILON
		and absf(car.steering_input) < VISUAL_IDLE_STEERING_EPSILON
		and absf(target_roll - _visual_roll_angle) < VISUAL_IDLE_ANGLE_EPSILON
		and absf(target_pitch - _visual_pitch_angle) < VISUAL_IDLE_ANGLE_EPSILON
	):
		return

	var pose_weight: float = clampf(delta * VISUAL_POSE_SMOOTH_RATE, 0.0, 1.0)
	_visual_roll_angle = lerpf(_visual_roll_angle, target_roll, pose_weight)
	_visual_pitch_angle = lerpf(_visual_pitch_angle, target_pitch, pose_weight)

	var aligned_basis: Basis = car.basis_from_forward_and_up(car.get_heading_forward(), _visual_surface_up)
	var visual_basis: Basis = aligned_basis
	visual_basis = visual_basis.rotated(visual_basis.x, _visual_pitch_angle)
	visual_basis = visual_basis.rotated(visual_basis.z, _visual_roll_angle)
	var target_local_rotation: Basis = car.global_basis.inverse() * visual_basis
	var target_visual_rotation: Basis = target_local_rotation * _visual_root_base_rotation
	var current_rotation: Basis = _visual_root.transform.basis.orthonormalized()
	var target_quaternion: Quaternion = target_visual_rotation.get_rotation_quaternion()
	var current_quaternion: Quaternion = current_rotation.get_rotation_quaternion()
	var visual_transform: Transform3D = _visual_root.transform
	visual_transform.basis = Basis(current_quaternion.slerp(target_quaternion, pose_weight)).scaled(_visual_root_base_scale)
	visual_transform.origin = visual_transform.origin.lerp(_visual_root_base_origin, pose_weight)
	_visual_root.transform = visual_transform


func _update_wheel_steering(delta: float) -> void:
	if _wheel_front_left == null or _wheel_front_right == null:
		return
	var steer_input: float = car.steering_input if car != null else 0.0
	var target_angle: float = steer_input * MAX_VISUAL_STEER_ANGLE
	var weight: float = clampf(delta * WHEEL_STEER_SMOOTH_RATE, 0.0, 1.0)
	_visual_steer_angle = lerpf(_visual_steer_angle, target_angle, weight)
	_wheel_front_left.rotation.y = _visual_steer_angle
	_wheel_front_right.rotation.y = _visual_steer_angle


func _cache_visual_rest_pose() -> void:
	if _visual_root == null:
		return
	_visual_root_base_origin = _visual_root.transform.origin
	_visual_root_base_scale = _visual_root.transform.basis.get_scale()
	_visual_root_base_rotation = _visual_root.transform.basis.orthonormalized()
	_rest_pose_cached = true


func _ensure_visual_root_pose() -> void:
	if _visual_root == null:
		return
	var visual_transform: Transform3D = _visual_root.transform
	visual_transform.origin = _visual_root_base_origin
	visual_transform.basis = _visual_root_base_rotation.scaled(_visual_root_base_scale)
	_visual_root.transform = visual_transform
