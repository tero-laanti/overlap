class_name CrosswindFan
extends Area3D

const RUN_STATE_GROUP := &"run_state"

@export var wind_strength: float = 18.0
@export var base_color: Color = Color(0.22, 0.24, 0.30, 1.0)
@export var accent_color: Color = Color(0.72, 0.88, 1.0, 1.0)
@export var preview_valid_color: Color = Color(0.52, 0.84, 1.0, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.44, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _run_state: RunState = null
var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _active_cars: Dictionary[int, Car] = {}
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
	_run_state = get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_configure_materials()
	_apply_visual_state()


func _physics_process(delta: float) -> void:
	if _preview_mode or _active_cars.is_empty():
		return
	if _run_state and not _run_state.is_round_active:
		return

	var push_direction: Vector3 = global_basis.x
	push_direction.y = 0.0
	if push_direction.length_squared() < 0.0001:
		push_direction = Vector3.RIGHT
	else:
		push_direction = push_direction.normalized()

	var stale_body_ids: Array[int] = []
	for body_id in _active_cars.keys():
		var car: Car = _active_cars[body_id]
		if not is_instance_valid(car):
			stale_body_ids.append(body_id)
			continue
		car.apply_planar_velocity_delta(push_direction * wind_strength * delta)

	for body_id in stale_body_ids:
		_active_cars.erase(body_id)


func set_preview_mode(is_preview: bool) -> void:
	if is_preview:
		_active_cars.clear()
	_preview_mode = is_preview
	if is_node_ready():
		_apply_visual_state()


func set_preview_valid(is_valid: bool) -> void:
	_preview_valid = is_valid
	if is_node_ready():
		_apply_visual_state()


func set_preview_focused(is_focused: bool) -> void:
	_preview_focused = is_focused
	if is_node_ready():
		_apply_visual_state()


func _on_body_entered(body: Node) -> void:
	var car: Car = CarBodyResolver.resolve(body)
	if _preview_mode or car == null:
		return
	if _run_state and not _run_state.is_round_active:
		return
	_active_cars[car.get_instance_id()] = car


func _on_body_exited(body: Node) -> void:
	var car: Car = CarBodyResolver.resolve(body)
	if car != null:
		_active_cars.erase(car.get_instance_id())


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.48, 0.1, 0.16, 0.02, 0.7)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.16))
	HazardPreviewHelper.apply_collision_state_area(self, collision_shape, _preview_mode)
