class_name MutationPreviewController
extends Node

## Owns the round-end track-mutation telegraph: the "Track Evolved"
## overlay, the highlight/ghost ribbons on the new and old racing lines,
## and the top-down camera framing of the spliced section. Main configures
## the controller once, then calls show_preview / hide_preview around the
## pit-stop flow. Input (continue/place_boost_pad to dismiss) stays in
## main so the preview does not fight the placement and hazard flows.

const MUTATION_PREVIEW_CAMERA_HEIGHT := 95.0
const MUTATION_PREVIEW_CAMERA_OFFSET := 14.0
const MUTATION_HIGHLIGHT_Y_OFFSET := 0.04
const MUTATION_HIGHLIGHT_COLOR := Color(1.0, 0.55, 0.88, 0.42)
const MUTATION_GHOST_Y_OFFSET := 0.025
const MUTATION_GHOST_COLOR := Color(0.9, 0.96, 1.0, 0.22)

var _track: TestTrack = null
var _camera: GameCamera = null
var _overlay: CanvasLayer = null
var _overlay_panel: PanelContainer = null
var _overlay_body: Label = null
var _highlight_mesh: MeshInstance3D = null
var _ghost_mesh: MeshInstance3D = null
var _is_active: bool = false


func configure(track: TestTrack, camera: GameCamera) -> void:
	_track = track
	_camera = camera


func is_active() -> bool:
	return _is_active


## Drops the camera onto the spliced section, spawns the highlight and
## ghost ribbons under the track, and reveals the "Track Evolved" panel.
## Callers are expected to hide their round-end screen first.
func show_preview(result: TrackMutationResult) -> void:
	if result == null:
		return

	_ensure_overlay()
	_position_camera(result.world_center)
	_spawn_highlight(result.centerline, result.original_centerline)

	if _overlay_body:
		var detour_label: String = result.display_name if not result.display_name.is_empty() else "new detour"
		_overlay_body.text = "Spliced in: %s" % detour_label
	if _overlay:
		_overlay.visible = true
	_is_active = true


## Tears the preview down. Safe to call when not active. Does not restore
## the game camera's follow target or any round-end UI; the caller handles
## those because the appropriate restore depends on run state (run over,
## round started, or user-dismissed).
func hide_preview() -> void:
	if not _is_active:
		if _overlay and _overlay.visible:
			_overlay.visible = false
		_clear_highlight()
		return

	_is_active = false
	if _overlay:
		_overlay.visible = false
	_clear_highlight()


func _position_camera(world_center: Vector3) -> void:
	if _camera == null:
		return

	_camera.target = null
	var camera_position: Vector3 = world_center \
		+ Vector3.UP * MUTATION_PREVIEW_CAMERA_HEIGHT \
		+ Vector3(0.0, 0.0, MUTATION_PREVIEW_CAMERA_OFFSET)
	_camera.global_position = camera_position
	_camera.look_at(world_center, Vector3.UP)


func _spawn_highlight(
	centerline_points: Array[Vector3],
	original_centerline_points: Array[Vector3]
) -> void:
	_clear_highlight()
	if _track == null:
		return

	_ghost_mesh = _spawn_ribbon(
		original_centerline_points,
		MUTATION_GHOST_COLOR,
		MUTATION_GHOST_Y_OFFSET,
		"MutationGhost",
		0
	)
	_highlight_mesh = _spawn_ribbon(
		centerline_points,
		MUTATION_HIGHLIGHT_COLOR,
		MUTATION_HIGHLIGHT_Y_OFFSET,
		"MutationHighlight",
		1
	)


func _clear_highlight() -> void:
	if _highlight_mesh != null and is_instance_valid(_highlight_mesh):
		_highlight_mesh.queue_free()
	_highlight_mesh = null
	if _ghost_mesh != null and is_instance_valid(_ghost_mesh):
		_ghost_mesh.queue_free()
	_ghost_mesh = null


func _spawn_ribbon(
	centerline_points: Array[Vector3],
	color: Color,
	y_offset: float,
	node_name: String,
	render_priority: int
) -> MeshInstance3D:
	if _track == null or centerline_points.size() < 2:
		return null

	var half_width: float = _track.track_width * 0.5
	var ribbon_mesh: Mesh = _build_ribbon_mesh(centerline_points, half_width, y_offset)
	if ribbon_mesh == null:
		return null

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = render_priority

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = ribbon_mesh
	mesh_instance.material_override = material
	_track.add_child(mesh_instance)
	return mesh_instance


func _build_ribbon_mesh(centerline_points: Array[Vector3], half_width: float, y_offset: float) -> Mesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y_lift: Vector3 = Vector3.UP * y_offset

	for index in range(centerline_points.size() - 1):
		var p0: Vector3 = centerline_points[index]
		var p1: Vector3 = centerline_points[index + 1]
		var perp_0: Vector3 = TestTrack.get_centerline_perpendicular(centerline_points, index)
		var perp_1: Vector3 = TestTrack.get_centerline_perpendicular(centerline_points, index + 1)

		var a: Vector3 = p0 + perp_0 * half_width + y_lift
		var b: Vector3 = p0 - perp_0 * half_width + y_lift
		var c: Vector3 = p1 - perp_1 * half_width + y_lift
		var d: Vector3 = p1 + perp_1 * half_width + y_lift

		surface_tool.set_normal(Vector3.UP)
		surface_tool.add_vertex(b)
		surface_tool.add_vertex(c)
		surface_tool.add_vertex(d)

		surface_tool.set_normal(Vector3.UP)
		surface_tool.add_vertex(b)
		surface_tool.add_vertex(d)
		surface_tool.add_vertex(a)

	return surface_tool.commit()


func _ensure_overlay() -> void:
	if _overlay != null and _overlay_panel != null and _overlay_body != null:
		return

	_overlay = CanvasLayer.new()
	_overlay.name = "MutationRevealOverlay"
	_overlay.layer = 4
	_overlay.visible = false
	add_child(_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	_overlay_panel = PanelContainer.new()
	_overlay_panel.name = "MutationRevealPanel"
	_overlay_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_panel.custom_minimum_size = Vector2(420.0, 0.0)
	_overlay_panel.add_theme_stylebox_override("panel", _create_overlay_style())
	center.add_child(_overlay_panel)

	var panel_margin: MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 28)
	panel_margin.add_theme_constant_override("margin_top", 22)
	panel_margin.add_theme_constant_override("margin_right", 28)
	panel_margin.add_theme_constant_override("margin_bottom", 22)
	_overlay_panel.add_child(panel_margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel_margin.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.name = "MutationRevealTitle"
	title_label.text = "Track Evolved"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.98, 1.0))
	vbox.add_child(title_label)

	_overlay_body = Label.new()
	_overlay_body.name = "MutationRevealBody"
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_body.add_theme_font_size_override("font_size", 22)
	_overlay_body.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0, 1.0))
	vbox.add_child(_overlay_body)

	var hint_label: Label = Label.new()
	hint_label.name = "MutationRevealHint"
	hint_label.text = "Space / Enter to continue"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 1.0))
	vbox.add_child(hint_label)


func _create_overlay_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18, 0.96)
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.65, 0.95, 0.78)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	style.shadow_size = 22
	return style
