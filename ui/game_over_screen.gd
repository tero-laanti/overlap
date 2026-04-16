class_name GameOverScreen
extends CanvasLayer

const PANEL_BG := Color(0.12, 0.07, 0.08, 0.98)
const PANEL_BORDER := Color(1.0, 0.42, 0.38, 0.65)
const PANEL_SHADOW := Color(0.0, 0.0, 0.0, 0.4)
const TITLE_COLOR := Color(1.0, 0.62, 0.55, 1.0)
const PRIMARY_TEXT := Color(0.96, 0.94, 0.94, 1.0)
const SECONDARY_TEXT := Color(0.84, 0.82, 0.86, 1.0)
const RESTART_ACCENT := Color(1.0, 0.55, 0.48, 1.0)

@export var run_state_path: NodePath
@export var lap_tracker_path: NodePath

var _run_state: RunState = null
var _lap_tracker: LapTracker = null

var _overlay: ColorRect = null
var _panel: PanelContainer = null
var _title_label: Label = null
var _stats_label: Label = null
var _hint_label: Label = null


func _ready() -> void:
	layer = 4
	visible = false
	_build_layout()

	_run_state = get_node_or_null(run_state_path) as RunState
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker

	if not _run_state:
		push_warning("GameOverScreen could not find the run state.")
		return

	if not _run_state.run_failed.is_connected(_on_run_failed):
		_run_state.run_failed.connect(_on_run_failed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("continue_round"):
		get_viewport().set_input_as_handled()
		_restart_run()


func _on_run_failed(last_round_number: int, final_currency: int) -> void:
	var laps_this_round: int = _lap_tracker.completed_laps if _lap_tracker else 0
	var rounds_survived: int = maxi(last_round_number - 1, 0)
	_stats_label.text = "Rounds cleared: %d\nFinal round: %d (%d laps)\nTotal bank: $%d" % [
		rounds_survived,
		last_round_number,
		laps_this_round,
		final_currency,
	]
	visible = true


func _restart_run() -> void:
	# Scene reload is the simplest prototype-friendly restart. Avoids having to
	# unwind placed hazards, boost pads, car state, etc. by hand.
	get_tree().reload_current_scene()


func _build_layout() -> void:
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0.03, 0.01, 0.02, 0.82)
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(460.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _create_panel_style(PANEL_BG, PANEL_BORDER))
	center.add_child(_panel)

	var panel_margin: MarginContainer = MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 32)
	panel_margin.add_theme_constant_override("margin_top", 28)
	panel_margin.add_theme_constant_override("margin_right", 32)
	panel_margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(panel_margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	panel_margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = "Run Over"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	vbox.add_child(_title_label)

	var subtitle: Label = Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "No laps completed before the timer ran out."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", SECONDARY_TEXT)
	vbox.add_child(subtitle)

	_stats_label = Label.new()
	_stats_label.name = "StatsLabel"
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_font_size_override("font_size", 20)
	_stats_label.add_theme_color_override("font_color", PRIMARY_TEXT)
	_stats_label.add_theme_constant_override("line_spacing", 6)
	vbox.add_child(_stats_label)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "Space / Enter to restart"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 18)
	_hint_label.add_theme_color_override("font_color", RESTART_ACCENT)
	vbox.add_child(_hint_label)


func _create_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = 22
	return style
