class_name WashGate
extends Area3D

const RUN_STATE_GROUP := &"run_state"

@export var base_color: Color = Color(0.14, 0.28, 0.22, 1.0)
@export var accent_color: Color = Color(0.48, 1.0, 0.82, 1.0)
@export var preview_valid_color: Color = Color(0.38, 0.94, 0.78, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.44, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _run_state: RunState = null
var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
	_run_state = get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

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


func set_preview_focused(is_focused: bool) -> void:
	_preview_focused = is_focused
	if is_node_ready():
		_apply_visual_state()


func _on_body_entered(body: Node) -> void:
	if _preview_mode or not (body is Car):
		return
	if _run_state and not _run_state.is_round_active:
		return

	(body as Car).clear_temporary_handling_modifiers()


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.38, 0.02, 0.1, 0.0, 0.82)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.2))
	HazardPreviewHelper.apply_collision_state_area(self, collision_shape, _preview_mode)
