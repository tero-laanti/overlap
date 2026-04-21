class_name CarPicker
extends Control

## "Choose your car" screen. Opened from the main menu, writes the selected
## index back to `GameSession.selected_car_index`, then returns to the main
## menu. Each card shows a 3D turntable of its option (hue-shifted if the
## option asks for it) plus the display name + tagline.

const MAIN_MENU_SCENE_PATH := "res://ui/main_menu.tscn"
const CARD_MIN_SIZE := Vector2(220.0, 400.0)
const PREVIEW_SIZE := Vector2i(220, 180)
const TURNTABLE_RATE := 0.55
const TURNTABLE_INITIAL_YAW := 0.35
## Framed for a scale=2 Kenney sedan (≈4m long) plus the smaller kart. Each
## `CarOption.preview_scale` tweaks the body down so sedans don't spill off
## the card while leaving the kart close to its authored size.
const PREVIEW_CAMERA_POSITION := Vector3(1.4, 1.7, 4.2)
const PREVIEW_CAMERA_LOOK_AT := Vector3(0.0, 0.35, 0.0)
const PREVIEW_LIGHT_DIRECTION := Vector3(-0.4, -1.0, -0.3)
const SELECTED_COLOR := Color(1.0, 0.92, 0.65, 1.0)
const SELECTED_BG := Color(0.18, 0.22, 0.32, 1.0)
const SELECTED_BORDER := Color(1.0, 0.92, 0.65, 0.9)
const UNSELECTED_BG := Color(0.10, 0.13, 0.18, 0.92)
const UNSELECTED_BORDER := Color(0.48, 0.58, 0.72, 0.5)

@onready var _card_row: HBoxContainer = $CenterContainer/VBox/CardRow
@onready var _back_button: Button = $CenterContainer/VBox/Footer/BackButton
@onready var _hint_label: Label = $CenterContainer/VBox/Footer/HintLabel
@onready var _header_label: Label = $CenterContainer/VBox/HeaderLabel

var _cards: Array[Button] = []
var _turntables: Array[Node3D] = []


func _ready() -> void:
	if _back_button != null and not _back_button.pressed.is_connected(_on_back):
		_back_button.pressed.connect(_on_back)
	_populate_cards()
	_apply_selection(_read_selected_index(), false)
	_refresh_hint()


func _process(delta: float) -> void:
	for turntable in _turntables:
		if turntable != null:
			turntable.rotate_y(TURNTABLE_RATE * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()
		return
	for card_index in _cards.size():
		var action_name: StringName = StringName("menu_car_%d" % (card_index + 1))
		if InputMap.has_action(action_name) and event.is_action_pressed(action_name):
			get_viewport().set_input_as_handled()
			_apply_selection(card_index, true)
			return


func _populate_cards() -> void:
	_cards.clear()
	_turntables.clear()
	if _card_row == null:
		return
	for child in _card_row.get_children():
		child.queue_free()

	var options: Array[CarOption] = CarOptions.get_options()
	for option_index in options.size():
		var card: Button = _build_card(options[option_index], option_index)
		_card_row.add_child(card)
		_cards.append(card)


func _build_card(option: CarOption, index: int) -> Button:
	var card: Button = Button.new()
	card.name = "Card%d" % (index + 1)
	card.custom_minimum_size = CARD_MIN_SIZE
	card.clip_contents = true
	card.focus_mode = Control.FOCUS_CLICK
	card.pressed.connect(_on_card_pressed.bind(index))

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "CardLayout"
	layout.anchor_right = 1.0
	layout.anchor_bottom = 1.0
	layout.offset_left = 12.0
	layout.offset_top = 12.0
	layout.offset_right = -12.0
	layout.offset_bottom = -12.0
	layout.add_theme_constant_override("separation", 10)
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(layout)

	layout.add_child(_build_preview(option))

	var name_label: Label = Label.new()
	name_label.text = option.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
	layout.add_child(name_label)

	var description_label: Label = Label.new()
	description_label.text = option.description
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.94))
	layout.add_child(description_label)

	if not option.controller_label.is_empty():
		var controller_label_node: Label = Label.new()
		controller_label_node.text = option.controller_label
		controller_label_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		controller_label_node.add_theme_font_size_override("font_size", 13)
		controller_label_node.add_theme_color_override("font_color", Color(0.74, 0.88, 1.0, 0.95))
		layout.add_child(controller_label_node)

	var hint_label: Label = Label.new()
	hint_label.text = "Press %d" % (index + 1)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.76, 0.88, 0.8))
	layout.add_child(hint_label)

	return card


func _build_preview(option: CarOption) -> SubViewportContainer:
	var container: SubViewportContainer = SubViewportContainer.new()
	container.name = "Preview"
	container.stretch = true
	container.custom_minimum_size = Vector2(PREVIEW_SIZE)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport: SubViewport = SubViewport.new()
	viewport.size = PREVIEW_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var world: Node3D = Node3D.new()
	world.name = "PreviewWorld"
	viewport.add_child(world)

	var camera: Camera3D = Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 35.0
	camera.transform = _transform_looking_at(PREVIEW_CAMERA_POSITION, PREVIEW_CAMERA_LOOK_AT)
	camera.current = true
	world.add_child(camera)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "PreviewLight"
	light.light_energy = 1.1
	light.shadow_enabled = false
	var light_origin: Vector3 = -PREVIEW_LIGHT_DIRECTION * 3.0
	light.transform = _transform_looking_at(light_origin, light_origin + PREVIEW_LIGHT_DIRECTION)
	world.add_child(light)

	var env: WorldEnvironment = WorldEnvironment.new()
	env.name = "PreviewEnv"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.1, 0.14, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.66, 1.0)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	world.add_child(env)

	var turntable: Node3D = Node3D.new()
	turntable.name = "Turntable"
	turntable.rotate_y(TURNTABLE_INITIAL_YAW)
	turntable.scale = Vector3.ONE * maxf(option.preview_scale, 0.01)
	world.add_child(turntable)
	_turntables.append(turntable)

	if option.body_scene != null:
		var body: Node3D = option.body_scene.instantiate() as Node3D
		if body != null:
			body.transform = option.body_transform
			turntable.add_child(body)
			if option.hue_shift > 0.0:
				var texture: Texture2D = CarOptions.get_colormap_texture(option.hue_shift)
				if texture != null:
					CarOptions.apply_colormap_override(body, texture)

	return container


func _on_card_pressed(index: int) -> void:
	_apply_selection(index, true)


func _apply_selection(index: int, persist: bool) -> void:
	var options: Array[CarOption] = CarOptions.get_options()
	if options.is_empty():
		return
	var safe_index: int = CarOptions.clamp_index(index)
	if persist:
		var session: Node = _get_game_session()
		if session != null:
			session.set("selected_car_index", safe_index)
	_refresh_card_styles(safe_index)


func _refresh_card_styles(selected_index: int) -> void:
	for card_index in _cards.size():
		var card: Button = _cards[card_index]
		if card == null:
			continue
		var is_selected: bool = card_index == selected_index
		var style: StyleBoxFlat = _make_card_style(is_selected)
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style)
		card.add_theme_stylebox_override("pressed", style)
		card.add_theme_stylebox_override("focus", style)
		if is_selected:
			card.add_theme_color_override("font_color", SELECTED_COLOR)
		else:
			card.remove_theme_color_override("font_color")


func _make_card_style(is_selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = SELECTED_BG if is_selected else UNSELECTED_BG
	style.border_color = SELECTED_BORDER if is_selected else UNSELECTED_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 12
	return style


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _refresh_hint() -> void:
	if _hint_label == null:
		return
	_hint_label.text = "1-%d: select  •  ESC: back" % maxi(_cards.size(), 1)


func _read_selected_index() -> int:
	var session: Node = _get_game_session()
	if session == null:
		return 0
	return int(session.get("selected_car_index"))


func _get_game_session() -> Node:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return null
	return scene_tree.root.get_node_or_null(^"GameSession")


## Builds a `Transform3D` whose basis looks from `origin` toward `target`
## (camera convention: forward = -Z). Implemented here so preview cameras and
## lights can be positioned before they enter the scene tree — `look_at` and
## `look_at_from_position` both read global transform and error out when the
## node has no parent yet.
static func _transform_looking_at(origin: Vector3, target: Vector3, up: Vector3 = Vector3.UP) -> Transform3D:
	var direction: Vector3 = target - origin
	if direction.length_squared() < 0.0001:
		return Transform3D(Basis.IDENTITY, origin)
	var basis: Basis = Basis.looking_at(direction, up)
	return Transform3D(basis, origin)
