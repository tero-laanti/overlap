class_name GravelSpill
extends Area3D

const RUN_STATE_GROUP := &"run_state"

@export_range(0.05, 1.0, 0.05) var speed_factor: float = 0.82
@export_range(0.05, 1.0, 0.05) var grip_multiplier: float = 0.72
@export var grip_refresh_duration: float = 0.18
@export var base_color: Color = Color(0.42, 0.30, 0.16, 1.0)
@export var accent_color: Color = Color(0.72, 0.54, 0.28, 1.0)
@export var preview_valid_color: Color = Color(0.78, 0.58, 0.32, 1.0)
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


func _physics_process(_delta: float) -> void:
	if _preview_mode or _active_cars.is_empty():
		return
	if _run_state and not _run_state.is_round_active:
		return

	# Speed cap is registered once on entry and held under this hazard's source
	# key until exit. Grip is refreshed because the Car clears the modifier
	# after `grip_refresh_duration`.
	var stale_body_ids: Array[int] = []
	for body_id in _active_cars.keys():
		var car: Car = _active_cars[body_id]
		if not is_instance_valid(car):
			stale_body_ids.append(body_id)
			continue
		car.apply_grip_penalty(grip_multiplier, grip_refresh_duration)

	for body_id in stale_body_ids:
		_active_cars.erase(body_id)


func set_preview_mode(is_preview: bool) -> void:
	if is_preview:
		_release_all_cars()
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

	var body_id: int = body.get_instance_id()
	_active_cars[body_id] = car
	_apply_speed_cap(car)
	car.apply_grip_penalty(grip_multiplier, grip_refresh_duration)


func _on_body_exited(body: Node) -> void:
	var body_id: int = body.get_instance_id()
	if not _active_cars.has(body_id):
		return
	var stored_car: Car = _active_cars[body_id]
	if is_instance_valid(stored_car):
		_clear_speed_cap(stored_car)
	_active_cars.erase(body_id)


func _release_all_cars() -> void:
	for car in _active_cars.values():
		if is_instance_valid(car):
			_clear_speed_cap(car)
	_active_cars.clear()


func _apply_speed_cap(car: Car) -> void:
	var source: StringName = _get_speed_cap_source()
	if car.has_method("set_speed_cap_for_source"):
		car.call("set_speed_cap_for_source", source, speed_factor)
		return
	car.set_speed_cap(speed_factor)


func _clear_speed_cap(car: Car) -> void:
	var source: StringName = _get_speed_cap_source()
	if car.has_method("clear_speed_cap_for_source"):
		car.call("clear_speed_cap_for_source", source)
		return
	car.clear_speed_cap()


func _get_speed_cap_source() -> StringName:
	return StringName("gravel_spill_%s" % get_instance_id())


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.95, 0.0, 0.6, 0.0, 0.4)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.12))
	HazardPreviewHelper.apply_collision_state_area(self, collision_shape, _preview_mode)
