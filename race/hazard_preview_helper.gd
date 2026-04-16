class_name HazardPreviewHelper
extends RefCounted


static func configure_materials(
	base_mesh: MeshInstance3D,
	accent_mesh: MeshInstance3D,
	base_mat: StandardMaterial3D,
	accent_mat: StandardMaterial3D,
	base_roughness: float,
	base_metallic: float,
	accent_roughness: float,
	accent_metallic: float,
	accent_emission_energy: float,
) -> void:
	base_mat.roughness = base_roughness
	base_mat.metallic = base_metallic
	accent_mat.roughness = accent_roughness
	accent_mat.metallic = accent_metallic
	accent_mat.emission_enabled = true
	accent_mat.emission_energy_multiplier = accent_emission_energy
	base_mesh.material_override = base_mat
	accent_mesh.material_override = accent_mat


static func apply_visual_state(
	base_mat: StandardMaterial3D,
	accent_mat: StandardMaterial3D,
	base_color: Color,
	accent_color: Color,
	preview_valid_color: Color,
	preview_invalid_color: Color,
	preview_mode: bool,
	preview_valid: bool,
	preview_focused: bool,
	accent_derive: Callable,
	unfocused_base_alpha: float = 0.55,
	unfocused_accent_alpha: float = 0.7,
) -> void:
	var current_base_color: Color = base_color
	var current_accent_color: Color = accent_color

	if preview_mode:
		current_base_color = preview_valid_color if preview_valid else preview_invalid_color
		current_accent_color = accent_derive.call(current_base_color) as Color
		if preview_focused:
			current_base_color.a = 1.0
			current_accent_color.a = 1.0
		else:
			current_base_color.a = unfocused_base_alpha
			current_accent_color.a = unfocused_accent_alpha

	base_mat.albedo_color = current_base_color
	accent_mat.albedo_color = current_accent_color
	accent_mat.emission = current_accent_color
	var use_alpha_preview: bool = preview_mode and not preview_focused
	base_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if use_alpha_preview else BaseMaterial3D.TRANSPARENCY_DISABLED
	accent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if use_alpha_preview else BaseMaterial3D.TRANSPARENCY_DISABLED


static func apply_collision_state_area(
	node: Area3D,
	shape: CollisionShape3D,
	preview_mode: bool,
) -> void:
	node.set_deferred("monitoring", not preview_mode)
	node.set_deferred("monitorable", not preview_mode)
	shape.set_deferred("disabled", preview_mode)


static func apply_collision_state_body(
	shape: CollisionShape3D,
	preview_mode: bool,
) -> void:
	shape.set_deferred("disabled", preview_mode)


static func set_preview(node: Node3D, mode: bool, valid: bool, focused: bool = false) -> void:
	if node.has_method("set_preview_mode"):
		node.call("set_preview_mode", mode)
	if node.has_method("set_preview_valid"):
		node.call("set_preview_valid", valid)
	if node.has_method("set_preview_focused"):
		node.call("set_preview_focused", focused)


static func set_preview_focus(node: Node3D, focused: bool) -> void:
	if node.has_method("set_preview_focused"):
		node.call("set_preview_focused", focused)
