class_name BoostPad
extends Area3D

const RUN_STATE_GROUP := &"run_state"

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


func _ready() -> void:
	_run_state = get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_configure_materials()
	_apply_visual_state()


func set_preview_mode(is_preview: bool) -> void:
	_preview_mode = is_preview
	if is_node_ready():
		_apply_visual_state()


func set_preview_valid(is_valid: bool) -> void:
	_preview_valid = is_valid
	if is_node_ready():
		_apply_visual_state()


func _on_body_entered(body: Node) -> void:
	if _preview_mode or not (body is Car):
		return
	if _run_state and not _run_state.is_round_active:
		return

	var body_id: int = body.get_instance_id()
	if _triggered_body_ids.has(body_id):
		return

	_triggered_body_ids[body_id] = true
	(body as Car).apply_forward_boost(boost_speed)


func _on_body_exited(body: Node) -> void:
	_triggered_body_ids.erase(body.get_instance_id())


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
