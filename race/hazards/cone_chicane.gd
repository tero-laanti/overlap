class_name ConeChicane
extends StaticBody3D

@export var base_color: Color = Color(0.82, 0.34, 0.14, 1.0)
@export var accent_color: Color = Color(1.0, 0.84, 0.28, 1.0)
@export var preview_valid_color: Color = Color(0.96, 0.72, 0.34, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.42, 0.38, 1.0)

var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _collision_shapes: Array[CollisionShape3D] = []
var _base_meshes: Array[MeshInstance3D] = []
var _accent_meshes: Array[MeshInstance3D] = []
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
	_collect_children()
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


func _collect_children() -> void:
	_collision_shapes.clear()
	_base_meshes.clear()
	_accent_meshes.clear()

	for child in get_children():
		if child is CollisionShape3D:
			_collision_shapes.append(child as CollisionShape3D)
		elif child is MeshInstance3D:
			if child.name.begins_with("BaseMesh"):
				_base_meshes.append(child as MeshInstance3D)
			elif child.name.begins_with("AccentMesh"):
				_accent_meshes.append(child as MeshInstance3D)


## Chicane owns several cone meshes per material, so it configures the two
## shared StandardMaterial3D instances directly and assigns them as overrides
## on every cone. `HazardPreviewHelper.configure_materials` only handles a
## single BaseMesh / AccentMesh pair; the visual-state path still uses the
## helper below.
func _configure_materials() -> void:
	_base_material.roughness = 0.56
	_base_material.metallic = 0.04
	_accent_material.roughness = 0.18
	_accent_material.metallic = 0.04
	_accent_material.emission_enabled = true
	_accent_material.emission_energy_multiplier = 0.55

	for mesh in _base_meshes:
		mesh.material_override = _base_material
	for mesh in _accent_meshes:
		mesh.material_override = _accent_material


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.12))

	for collision_shape in _collision_shapes:
		collision_shape.set_deferred("disabled", _preview_mode)
