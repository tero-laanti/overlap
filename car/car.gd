class_name Car
extends Node3D

## Abstract base for vehicle controllers. Concrete subclasses (`SphereCar`,
## `PhysicsCar`, …) implement their own physics model. This class declares
## the public surface that hazards, HUD, pit stop, lap tracker, camera, and
## pause menu consume, plus small shared defaults so subclasses only override
## what actually differs.

signal drift_started
signal drift_ended
signal body_entered(body: Node)
signal body_exited(body: Node)
signal body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int)

const DRIFT_FEEDBACK_NODE := "DriftFeedback"
const BODY_NODE_NAME := &"Body"
const VISUAL_POSE_NODE := "CarVisualPose"

@export var stats: CarStats

var steering_input: float = 0.0
var throttle_input: float = 0.0
var is_drifting: bool = false
var controls_enabled: bool = true
var is_grounded: bool = false
var ground_normal: Vector3 = Vector3.UP

var linear_velocity: Vector3:
	get:
		if _physics_proxy == null:
			return Vector3.ZERO
		return _physics_proxy.linear_velocity
	set(value):
		if _physics_proxy != null:
			_physics_proxy.linear_velocity = value

var angular_velocity: Vector3:
	get:
		if _physics_proxy == null:
			return Vector3.ZERO
		return _physics_proxy.angular_velocity
	set(value):
		if _physics_proxy != null:
			_physics_proxy.angular_velocity = value

var _is_frozen: bool = false
var _visual_pose: CarVisualPose = null

@onready var _physics_proxy: CarPhysicsProxy = get_node_or_null(^"PhysicsProxy") as CarPhysicsProxy
@onready var _ground_probe: RayCast3D = get_node_or_null(^"GroundProbe") as RayCast3D
@onready var _visual_root: Node3D = get_node_or_null(^"VisualRoot") as Node3D


func _ready() -> void:
	if stats == null:
		stats = load("res://car/default_stats.tres")
	if _physics_proxy != null:
		_physics_proxy.bind_car(self)
		if _ground_probe != null:
			_ground_probe.add_exception(_physics_proxy)
	_spawn_selected_body()
	_ensure_visual_pose()
	_ensure_drift_feedback()


## Virtual: concrete controllers return their proxy-specific ground offset so
## the spawned body sits at the right Y for the sphere vs. box proxy without
## each `CarOption` having to author per-controller transforms.
func _get_body_base_y_offset() -> float:
	return 0.0


## Instantiates the `Body` node under `VisualRoot` from the currently-selected
## `CarOption`. Any authored `Body` in the `.tscn` is cleared first so scene
## files can leave the slot empty. Safe to call multiple times — used both at
## `_ready` and if a future feature swaps the body mid-run.
func _spawn_selected_body() -> void:
	if _visual_root == null:
		return

	var existing_body: Node = _visual_root.get_node_or_null(NodePath(BODY_NODE_NAME))
	if existing_body != null:
		_visual_root.remove_child(existing_body)
		existing_body.queue_free()

	var selected_index: int = _read_selected_car_index()
	var option: CarOption = CarOptions.get_option(selected_index)
	if option == null or option.body_scene == null:
		push_warning("Car has no valid CarOption for index %d." % selected_index)
		return

	var body: Node3D = option.body_scene.instantiate() as Node3D
	if body == null:
		push_warning("Car failed to instantiate body for option %s." % option.display_name)
		return
	body.name = BODY_NODE_NAME
	_visual_root.add_child(body)

	var body_transform: Transform3D = option.body_transform
	body_transform.origin.y += _get_body_base_y_offset()
	body.transform = body_transform

	if option.hue_shift > 0.0:
		var texture: Texture2D = CarOptions.get_colormap_texture(option.hue_shift)
		if texture != null:
			CarOptions.apply_colormap_override(body, texture)


## Autoloads (`GameSession`) don't always resolve as a bare identifier during
## the `update_scripts_classes` phase — the dependency chain that reloads
## `car.gd` can fire before the autoload is registered. Go through the scene
## tree like `main.gd._get_game_session` does to stay robust.
func _read_selected_car_index() -> int:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return 0
	var game_session: Node = scene_tree.root.get_node_or_null(^"GameSession")
	if game_session == null:
		return 0
	return int(game_session.get("selected_car_index"))


func _ensure_visual_pose() -> void:
	var visual_pose: CarVisualPose = get_node_or_null(NodePath(VISUAL_POSE_NODE)) as CarVisualPose
	if visual_pose == null:
		visual_pose = CarVisualPose.new()
		visual_pose.name = VISUAL_POSE_NODE
		add_child(visual_pose)
	_visual_pose = visual_pose
	_visual_pose.bind_car(self)


## Invoked by `CarPhysicsProxy._integrate_forces` on the physics tick. Legacy
## integrator-based controllers apply forces here; arcade controllers that
## drive from `_physics_process` leave it as the no-op default.
func _integrate_proxy_forces(_state: PhysicsDirectBodyState3D) -> void:
	pass


## Base implementation handles the transform + physics-interp reset so
## subclasses only add their per-controller cleanup (internal buffers, drift
## state, heading, proxy teleport, …).
func reset_to_transform(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	reset_physics_interpolation()


func set_controls_enabled(is_enabled: bool) -> void:
	controls_enabled = is_enabled
	if not controls_enabled:
		steering_input = 0.0
		throttle_input = 0.0


func set_frozen(should_freeze: bool) -> void:
	_is_frozen = should_freeze
	if _physics_proxy == null:
		return
	_physics_proxy.freeze = should_freeze
	if should_freeze:
		_physics_proxy.linear_velocity = Vector3.ZERO
		_physics_proxy.angular_velocity = Vector3.ZERO
	else:
		_physics_proxy.sleeping = false


func is_frozen() -> bool:
	return _is_frozen


## Arcade-style forward nudge along the car's current heading. Subclasses may
## override to preserve vertical velocity, respect a speed cap, etc.
func apply_forward_boost(boost_speed: float) -> void:
	if boost_speed <= 0.0 or _physics_proxy == null:
		return
	var forward: Vector3 = -global_basis.z
	_physics_proxy.linear_velocity += forward * boost_speed
	_physics_proxy.sleeping = false


func apply_planar_velocity_delta(delta_velocity: Vector3) -> void:
	if _is_frozen or _physics_proxy == null:
		return
	var planar: Vector3 = delta_velocity
	planar.y = 0.0
	_physics_proxy.linear_velocity += planar
	_physics_proxy.sleeping = false


## Handling-modifier hooks default to no-ops. Controllers with an internal
## grip / speed-cap model override these; arcade controllers that don't model
## grip simply ignore them.

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
	return _physics_proxy


func has_full_ground_support() -> bool:
	return is_grounded


func get_support_up_axis() -> Vector3:
	return ground_normal if is_grounded else Vector3.UP


func get_drive_forward_vector(up_axis: Vector3) -> Vector3:
	var forward: Vector3 = -global_basis.z
	var planar: Vector3 = forward.slide(up_axis)
	if planar.length_squared() < 0.0001:
		return Vector3.FORWARD
	return planar.normalized()


func get_heading_forward() -> Vector3:
	return get_drive_forward_vector(Vector3.UP)


## Hoisted from the concrete controllers so every `Car` subclass gets drift
## smoke for free. Parents under `VisualRoot` so the emitter inherits the
## Car's yaw frame; per-vehicle offset tweaks (Y compensation for Car-root
## offset, different rear-wheel positions) happen via
## `_configure_drift_feedback`.
func _ensure_drift_feedback() -> void:
	if _visual_root == null:
		return
	var existing: DriftFeedback = _visual_root.get_node_or_null(DRIFT_FEEDBACK_NODE) as DriftFeedback
	if existing != null:
		_configure_drift_feedback(existing)
		existing.bind_car(self)
		return
	var feedback: DriftFeedback = DriftFeedback.new()
	feedback.name = DRIFT_FEEDBACK_NODE
	_configure_drift_feedback(feedback)
	_visual_root.add_child(feedback)
	feedback.bind_car(self)


## Override to adjust per-vehicle smoke emitter offsets. Default no-op keeps
## `DriftFeedback`'s sedan-tuned @export defaults, which assume Car root at
## world Y=0 (SphereCar). Called before `bind_car` so changes take effect
## on the first particle spawn.
func _configure_drift_feedback(_feedback: DriftFeedback) -> void:
	pass


# -- Signal relays called by `CarPhysicsProxy`.

func _relay_proxy_body_entered(body: Node) -> void:
	body_entered.emit(body)


func _relay_proxy_body_exited(body: Node) -> void:
	body_exited.emit(body)


func _relay_proxy_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	body_shape_entered.emit(body_rid, body, body_shape_index, local_shape_index)
