class_name WallBarrier
extends StaticBody3D

const HazardPreviewHelper := preload("res://race/hazard_preview_helper.gd")

@export var base_color: Color = Color(0.78, 0.22, 0.14, 1.0)
@export var accent_color: Color = Color(0.98, 0.58, 0.22, 1.0)
@export var preview_valid_color: Color = Color(0.96, 0.66, 0.28, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.42, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
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


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.6, 0.05, 0.35, 0.08, 0.45)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.14))
	HazardPreviewHelper.apply_collision_state_body(collision_shape, _preview_mode)
