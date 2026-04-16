class_name OilSlick
extends Area3D

const HazardPreviewHelper := preload("res://race/hazard_preview_helper.gd")
const RUN_STATE_GROUP := &"run_state"

@export_range(0.05, 1.0, 0.05) var grip_multiplier: float = 0.3
@export var penalty_duration: float = 1.5
@export var base_color: Color = Color(0.18, 0.24, 0.18, 1.0)
@export var accent_color: Color = Color(0.10, 0.14, 0.10, 1.0)
@export var preview_valid_color: Color = Color(0.34, 0.46, 0.34, 1.0)
@export var preview_invalid_color: Color = Color(0.96, 0.44, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _run_state: RunState = null
var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
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


func set_preview_focused(is_focused: bool) -> void:
	_preview_focused = is_focused
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
	(body as Car).apply_grip_penalty(grip_multiplier, penalty_duration)


func _on_body_exited(body: Node) -> void:
	_triggered_body_ids.erase(body.get_instance_id())


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		1.0, 0.0, 0.7, 0.0, 0.35)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.darkened(0.22))
	HazardPreviewHelper.apply_collision_state_area(self, collision_shape, _preview_mode)
