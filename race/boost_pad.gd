class_name BoostPad
extends Area3D

const RUN_STATE_GROUP := &"run_state"
const FOOTPRINT_HALF_EXTENTS := Vector2(1.3, 2.3)

@export var boost_speed: float = 11.0
@export var base_color: Color = Color(0.34, 0.36, 0.40, 1.0)
@export var accent_color: Color = Color(0.45, 0.95, 1.0, 1.0)
@export var preview_valid_color: Color = Color(0.55, 0.96, 0.68, 1.0)
@export var preview_invalid_color: Color = Color(1.0, 0.45, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _run_state: RunState = null
var _preview_mode: bool = false
var _preview_valid: bool = true
var _triggered_body_ids: Dictionary[int, bool] = {}
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()


static func footprints_overlap(a_transform: Transform3D, b_transform: Transform3D, clearance: float = 0.0) -> bool:
	var a_center: Vector2 = Vector2(a_transform.origin.x, a_transform.origin.z)
	var b_center: Vector2 = Vector2(b_transform.origin.x, b_transform.origin.z)
	var a_axes: Array[Vector2] = _get_footprint_axes(a_transform)
	var b_axes: Array[Vector2] = _get_footprint_axes(b_transform)
	var a_half_extents: Vector2 = FOOTPRINT_HALF_EXTENTS + Vector2.ONE * clearance
	var b_half_extents: Vector2 = FOOTPRINT_HALF_EXTENTS + Vector2.ONE * clearance
	var center_delta: Vector2 = b_center - a_center
	var test_axes: Array[Vector2] = [a_axes[0], a_axes[1], b_axes[0], b_axes[1]]

	for axis in test_axes:
		var distance: float = absf(center_delta.dot(axis))
		var radius_a: float = _project_footprint_radius(axis, a_axes, a_half_extents)
		var radius_b: float = _project_footprint_radius(axis, b_axes, b_half_extents)
		if distance >= radius_a + radius_b:
			return false

	return true


func _ready() -> void:
	_run_state = get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_configure_materials()
	_apply_visual_state()


func set_preview_mode(is_preview: bool) -> void:
	if is_preview:
		_triggered_body_ids.clear()
	_preview_mode = is_preview
	if is_node_ready():
		_apply_visual_state()


func set_preview_valid(is_valid: bool) -> void:
	_preview_valid = is_valid
	if is_node_ready():
		_apply_visual_state()


func _on_body_entered(body: Node) -> void:
	var car: Car = CarBodyResolver.resolve(body)
	if _preview_mode or car == null:
		return
	if _run_state and not _run_state.is_round_active:
		return
	_prune_triggered_bodies()

	var car_id: int = car.get_instance_id()
	if _triggered_body_ids.has(car_id):
		return

	_triggered_body_ids[car_id] = true
	car.apply_forward_boost(boost_speed)


func _on_body_exited(body: Node) -> void:
	var car: Car = CarBodyResolver.resolve(body)
	if car != null:
		_triggered_body_ids.erase(car.get_instance_id())


func _prune_triggered_bodies() -> void:
	var stale_body_ids: Array[int] = []
	for body_id in _triggered_body_ids.keys():
		if instance_from_id(body_id) == null:
			stale_body_ids.append(body_id)

	for body_id in stale_body_ids:
		_triggered_body_ids.erase(body_id)


func _configure_materials() -> void:
	_base_material.roughness = 0.35
	_base_material.metallic = 0.15
	_accent_material.roughness = 0.15
	_accent_material.metallic = 0.1
	_accent_material.emission_enabled = true
	_accent_material.emission_energy_multiplier = 0.7
	base_mesh.material_override = _base_material
	accent_mesh.material_override = _accent_material


func _apply_visual_state() -> void:
	var current_base_color: Color = base_color
	var current_accent_color: Color = accent_color

	if _preview_mode:
		current_base_color = preview_valid_color if _preview_valid else preview_invalid_color
		current_accent_color = current_base_color.lightened(0.18)
		current_base_color.a = 0.55
		current_accent_color.a = 0.65

	_base_material.albedo_color = current_base_color
	_accent_material.albedo_color = current_accent_color
	_accent_material.emission = current_accent_color
	_base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _preview_mode else BaseMaterial3D.TRANSPARENCY_DISABLED
	_accent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if _preview_mode else BaseMaterial3D.TRANSPARENCY_DISABLED
	set_deferred("monitoring", not _preview_mode)
	set_deferred("monitorable", not _preview_mode)
	collision_shape.set_deferred("disabled", _preview_mode)


static func _get_footprint_axes(pad_transform: Transform3D) -> Array[Vector2]:
	var right: Vector2 = Vector2(pad_transform.basis.x.x, pad_transform.basis.x.z)
	var forward: Vector2 = Vector2(pad_transform.basis.z.x, pad_transform.basis.z.z)
	if right.length_squared() < 0.001:
		right = Vector2.RIGHT
	else:
		right = right.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector2.UP
	else:
		forward = forward.normalized()
	return [right, forward]


static func _project_footprint_radius(axis: Vector2, footprint_axes: Array[Vector2], half_extents: Vector2) -> float:
	return absf(axis.dot(footprint_axes[0])) * half_extents.x \
		+ absf(axis.dot(footprint_axes[1])) * half_extents.y
