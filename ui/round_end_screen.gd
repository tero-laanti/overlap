class_name RoundEndScreen
extends CanvasLayer

const HazardTypeRegistry := preload("res://race/hazard_type.gd")
const PositiveTypeRegistry := preload("res://race/positive_type.gd")
const COMPACT_LAYOUT_MIN_VIEWPORT_HEIGHT := 760.0
const COMPACT_LAYOUT_MIN_VIEWPORT_WIDTH := 1366.0
const DEFAULT_PANEL_MIN_WIDTH := 520.0
const MIN_PANEL_WIDTH := 360.0
const DEFAULT_PANEL_MARGIN := 32
const COMPACT_PANEL_MARGIN := 22
const DEFAULT_SECTION_SEPARATION := 18
const COMPACT_SECTION_SEPARATION := 12
const DEFAULT_ACTION_BUTTON_HEIGHT := 84.0
const COMPACT_ACTION_BUTTON_HEIGHT := 68.0
const DEFAULT_HAZARD_BUTTON_HEIGHT := 94.0
const COMPACT_HAZARD_BUTTON_HEIGHT := 78.0
const DEFAULT_TITLE_FONT_SIZE := 40
const COMPACT_TITLE_FONT_SIZE := 34
const DEFAULT_SUBTITLE_FONT_SIZE := 18
const COMPACT_SUBTITLE_FONT_SIZE := 16
const DEFAULT_SECTION_TITLE_FONT_SIZE := 15
const COMPACT_SECTION_TITLE_FONT_SIZE := 13
const DEFAULT_STATS_FONT_SIZE := 20
const COMPACT_STATS_FONT_SIZE := 18
const DEFAULT_NEXT_ROUND_FONT_SIZE := 18
const COMPACT_NEXT_ROUND_FONT_SIZE := 16
const DEFAULT_ACTION_FONT_SIZE := 20
const COMPACT_ACTION_FONT_SIZE := 18
const DEFAULT_PENDING_FONT_SIZE := 16
const COMPACT_PENDING_FONT_SIZE := 15
const DEFAULT_CONTINUE_FONT_SIZE := 18
const COMPACT_CONTINUE_FONT_SIZE := 16
const DEFAULT_HAZARD_TITLE_FONT_SIZE := 22
const COMPACT_HAZARD_TITLE_FONT_SIZE := 20
const DEFAULT_HAZARD_SECTION_SEPARATION := 10
const COMPACT_HAZARD_SECTION_SEPARATION := 8
const DEFAULT_HAZARD_BUTTON_FONT_SIZE := 17
const COMPACT_HAZARD_BUTTON_FONT_SIZE := 15

const PANEL_BG := Color(0.1, 0.12, 0.16, 0.96)
const PANEL_BORDER := Color(1.0, 0.89, 0.64, 0.38)
const PANEL_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.34)
const SUMMARY_BG := Color(0.13, 0.16, 0.22, 0.98)
const SUMMARY_BORDER := Color(0.55, 0.71, 0.92, 0.34)
const QUEUE_BG := Color(0.11, 0.18, 0.15, 0.98)
const QUEUE_BORDER := Color(0.62, 0.94, 0.75, 0.28)
const FOOTER_BG := Color(0.12, 0.14, 0.18, 0.98)
const FOOTER_BORDER := Color(0.56, 0.65, 0.8, 0.24)
const PRIMARY_TEXT_COLOR := Color(0.94, 0.95, 0.98, 1.0)
const SUBTITLE_TEXT_COLOR := Color(0.73, 0.82, 0.9, 1.0)
const SECTION_TEXT_COLOR := Color(1.0, 0.86, 0.7, 1.0)
const SUMMARY_TEXT_COLOR := Color(0.93, 0.95, 0.98, 1.0)
const NEXT_ROUND_TEXT_COLOR := Color(0.78, 0.92, 1.0, 1.0)
const CONTINUE_TEXT_COLOR := Color(0.84, 0.87, 0.92, 1.0)
const BLOCKED_TEXT_COLOR := Color(1.0, 0.72, 0.68, 1.0)
const UTILITY_ACCENT := Color(0.48, 0.84, 1.0, 1.0)
const GREED_ACCENT := Color(1.0, 0.84, 0.34, 1.0)
const HANDLING_ACCENT := Color(0.46, 0.96, 0.82, 1.0)
const HAZARD_ACCENT := Color(1.0, 0.68, 0.56, 1.0)
const POSITIVE_SHORTCUTS := ["Q", "W", "E"]

signal positive_offer_requested(offer_index: int)
signal hazard_drafted(hazard_type: int)
signal continue_requested

@export var run_state_path: NodePath
@export var lap_tracker_path: NodePath

@onready var overlay: ColorRect = $Overlay
@onready var panel: PanelContainer = $Center/Panel
@onready var panel_margin: MarginContainer = $Center/Panel/Margin
@onready var options_box: VBoxContainer = $Center/Panel/Margin/VBox
@onready var title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var stats_label: Label = $Center/Panel/Margin/VBox/StatsLabel
@onready var next_round_label: Label = $Center/Panel/Margin/VBox/NextRoundLabel
@onready var buy_time_button: Button = $Center/Panel/Margin/VBox/BuyTimeButton
@onready var continue_label: Label = $Center/Panel/Margin/VBox/ContinueLabel

var _run_state: RunState = null
var _lap_tracker: LapTracker = null
var _positive_offers: Array[int] = []
var _positive_offer_buttons: Array[Button] = []
var _pending_positive_types: Array[int] = []
var _hazard_draft_section: VBoxContainer = null
var _hazard_draft_title: Label = null
var _hazard_draft_buttons: Array[Button] = []
var _hazard_draft_options: Array[int] = []
var _selected_hazard_type: int = HazardTypeRegistry.NONE
var _requires_hazard_draft: bool = false
var _pending_items_label: Label = null
var _subtitle_label: Label = null
var _shop_section_label: Label = null
var _summary_panel: PanelContainer = null
var _summary_content: VBoxContainer = null
var _queued_panel: PanelContainer = null
var _footer_panel: PanelContainer = null
var _layout_built: bool = false


func _ready() -> void:
	visible = false
	_ensure_dynamic_controls()
	_build_visual_layout()
	_run_state = get_node_or_null(run_state_path) as RunState
	_lap_tracker = get_node_or_null(lap_tracker_path) as LapTracker

	if not _run_state:
		push_warning("RoundEndScreen could not find the run state.")
	else:
		if not _run_state.round_finished.is_connected(_on_round_finished):
			_run_state.round_finished.connect(_on_round_finished)
		if not _run_state.round_started.is_connected(_on_round_started):
			_run_state.round_started.connect(_on_round_started)
		if not _run_state.currency_changed.is_connected(_on_currency_changed):
			_run_state.currency_changed.connect(_on_currency_changed)
		if not _run_state.time_bank_cost_changed.is_connected(_on_time_bank_cost_changed):
			_run_state.time_bank_cost_changed.connect(_on_time_bank_cost_changed)

	if not _lap_tracker:
		push_warning("RoundEndScreen could not find the lap tracker.")

	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)

	_apply_responsive_layout()
	_refresh_display()


func configure_positive_offers(offers: Array[int]) -> void:
	_positive_offers = offers.duplicate()
	_refresh_display()


func clear_positive_offers() -> void:
	_positive_offers.clear()
	_refresh_display()


func configure_hazard_draft(options: Array[int]) -> void:
	_hazard_draft_options = options.duplicate()
	_selected_hazard_type = HazardTypeRegistry.NONE
	_requires_hazard_draft = not _hazard_draft_options.is_empty()
	_refresh_display()


func clear_hazard_draft() -> void:
	_hazard_draft_options.clear()
	_selected_hazard_type = HazardTypeRegistry.NONE
	_requires_hazard_draft = false
	_refresh_display()


func set_pending_positive_types(pending_positive_types: Array[int]) -> void:
	_pending_positive_types = pending_positive_types.duplicate()
	_refresh_display()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return

	if event.is_action_pressed("draft_hazard_1"):
		get_viewport().set_input_as_handled()
		_select_hazard_draft_index(0)
	elif event.is_action_pressed("draft_hazard_2"):
		get_viewport().set_input_as_handled()
		_select_hazard_draft_index(1)
	elif event.is_action_pressed("draft_hazard_3"):
		get_viewport().set_input_as_handled()
		_select_hazard_draft_index(2)
	elif event.is_action_pressed("buy_offer_1"):
		get_viewport().set_input_as_handled()
		_request_positive_offer(0)
	elif event.is_action_pressed("buy_offer_2"):
		get_viewport().set_input_as_handled()
		_request_positive_offer(1)
	elif event.is_action_pressed("buy_offer_3"):
		get_viewport().set_input_as_handled()
		_request_positive_offer(2)
	elif event.is_action_pressed("continue_round"):
		get_viewport().set_input_as_handled()
		if _can_continue():
			continue_requested.emit()


func _on_round_finished() -> void:
	visible = true
	_refresh_display()


func _on_round_started(_round_number: int) -> void:
	visible = false


func _on_currency_changed(_currency: int) -> void:
	_refresh_display()


func _on_time_bank_cost_changed(_cost: int) -> void:
	_refresh_display()


func _ensure_dynamic_controls() -> void:
	if _positive_offer_buttons.is_empty():
		buy_time_button.focus_mode = Control.FOCUS_NONE
		if not buy_time_button.pressed.is_connected(_on_positive_offer_button_pressed.bind(0)):
			buy_time_button.pressed.connect(_on_positive_offer_button_pressed.bind(0))
		_positive_offer_buttons.append(buy_time_button)

		for offer_index in range(1, POSITIVE_SHORTCUTS.size()):
			var positive_button: Button = Button.new()
			positive_button.name = "PositiveOfferButton%d" % (offer_index + 1)
			positive_button.focus_mode = Control.FOCUS_NONE
			if not positive_button.pressed.is_connected(_on_positive_offer_button_pressed.bind(offer_index)):
				positive_button.pressed.connect(_on_positive_offer_button_pressed.bind(offer_index))
			options_box.add_child(positive_button)
			options_box.move_child(positive_button, continue_label.get_index())
			_positive_offer_buttons.append(positive_button)

	if _pending_items_label == null:
		_pending_items_label = Label.new()
		_pending_items_label.name = "PendingItemsLabel"
		_pending_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_pending_items_label.add_theme_font_size_override("font_size", 18)
		_pending_items_label.add_theme_color_override("font_color", Color(0.87, 1.0, 0.77, 1.0))
		options_box.add_child(_pending_items_label)
		options_box.move_child(_pending_items_label, continue_label.get_index())

	if _hazard_draft_section == null:
		_hazard_draft_section = VBoxContainer.new()
		_hazard_draft_section.name = "HazardDraftSection"
		options_box.add_child(_hazard_draft_section)
		options_box.move_child(_hazard_draft_section, continue_label.get_index())

		_hazard_draft_title = Label.new()
		_hazard_draft_title.name = "HazardDraftTitle"
		_hazard_draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hazard_draft_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.72, 1.0))
		_hazard_draft_title.text = "Draft a Hazard"
		_hazard_draft_section.add_child(_hazard_draft_title)

		for index in range(HazardTypeRegistry.get_available_types().size()):
			var hazard_button: Button = Button.new()
			hazard_button.name = "HazardDraftButton%d" % (index + 1)
			hazard_button.focus_mode = Control.FOCUS_NONE
			if not hazard_button.pressed.is_connected(_on_hazard_draft_button_pressed.bind(index)):
				hazard_button.pressed.connect(_on_hazard_draft_button_pressed.bind(index))
			_hazard_draft_section.add_child(hazard_button)
			_hazard_draft_buttons.append(hazard_button)

	_reorder_dynamic_controls()


func _build_visual_layout() -> void:
	if _layout_built:
		return

	overlay.color = Color(0.02, 0.03, 0.05, 0.8)
	panel.add_theme_stylebox_override("panel", _create_panel_style(PANEL_BG, PANEL_BORDER))
	title_label.text = "Pit Stop"
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82, 1.0))

	if _subtitle_label == null:
		_subtitle_label = Label.new()
		_subtitle_label.name = "SubtitleLabel"
		_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_subtitle_label.text = "Buy track tech, queue placements, then draft the next problem."
		_subtitle_label.add_theme_color_override("font_color", SUBTITLE_TEXT_COLOR)
		options_box.add_child(_subtitle_label)

	if _summary_panel == null:
		_summary_panel = PanelContainer.new()
		_summary_panel.name = "SummaryPanel"
		_summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_summary_panel.add_theme_stylebox_override("panel", _create_panel_style(SUMMARY_BG, SUMMARY_BORDER))
		options_box.add_child(_summary_panel)

		var summary_margin: MarginContainer = MarginContainer.new()
		summary_margin.add_theme_constant_override("margin_left", 18)
		summary_margin.add_theme_constant_override("margin_top", 16)
		summary_margin.add_theme_constant_override("margin_right", 18)
		summary_margin.add_theme_constant_override("margin_bottom", 16)
		_summary_panel.add_child(summary_margin)

		_summary_content = VBoxContainer.new()
		_summary_content.name = "SummaryContent"
		_summary_content.add_theme_constant_override("separation", 8)
		summary_margin.add_child(_summary_content)
		_move_control(stats_label, _summary_content)
		_move_control(next_round_label, _summary_content)
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		next_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if _shop_section_label == null:
		_shop_section_label = Label.new()
		_shop_section_label.name = "ShopSectionLabel"
		_shop_section_label.text = "Buy Track Setup"
		_shop_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_shop_section_label.add_theme_color_override("font_color", SECTION_TEXT_COLOR)
		options_box.add_child(_shop_section_label)

	if _queued_panel == null:
		_queued_panel = PanelContainer.new()
		_queued_panel.name = "QueuedPanel"
		_queued_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_queued_panel.add_theme_stylebox_override("panel", _create_panel_style(QUEUE_BG, QUEUE_BORDER))
		options_box.add_child(_queued_panel)

		var queued_margin: MarginContainer = MarginContainer.new()
		queued_margin.add_theme_constant_override("margin_left", 14)
		queued_margin.add_theme_constant_override("margin_top", 12)
		queued_margin.add_theme_constant_override("margin_right", 14)
		queued_margin.add_theme_constant_override("margin_bottom", 12)
		_queued_panel.add_child(queued_margin)
		_move_control(_pending_items_label, queued_margin)
		_pending_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if _footer_panel == null:
		_footer_panel = PanelContainer.new()
		_footer_panel.name = "FooterPanel"
		_footer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_footer_panel.add_theme_stylebox_override("panel", _create_panel_style(FOOTER_BG, FOOTER_BORDER))
		options_box.add_child(_footer_panel)

		var footer_margin: MarginContainer = MarginContainer.new()
		footer_margin.add_theme_constant_override("margin_left", 14)
		footer_margin.add_theme_constant_override("margin_top", 12)
		footer_margin.add_theme_constant_override("margin_right", 14)
		footer_margin.add_theme_constant_override("margin_bottom", 12)
		_footer_panel.add_child(footer_margin)
		_move_control(continue_label, footer_margin)

	_reorder_static_sections()
	_layout_built = true


func _apply_responsive_layout() -> void:
	if not is_node_ready():
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var use_compact_layout: bool = viewport_size.y <= COMPACT_LAYOUT_MIN_VIEWPORT_HEIGHT \
		or viewport_size.x <= COMPACT_LAYOUT_MIN_VIEWPORT_WIDTH
	var panel_margin_size: int = COMPACT_PANEL_MARGIN if use_compact_layout else DEFAULT_PANEL_MARGIN
	var section_separation: int = COMPACT_SECTION_SEPARATION if use_compact_layout else DEFAULT_SECTION_SEPARATION
	var action_button_height: float = COMPACT_ACTION_BUTTON_HEIGHT if use_compact_layout else DEFAULT_ACTION_BUTTON_HEIGHT
	var hazard_button_height: float = COMPACT_HAZARD_BUTTON_HEIGHT if use_compact_layout else DEFAULT_HAZARD_BUTTON_HEIGHT

	panel.custom_minimum_size = Vector2(
		minf(DEFAULT_PANEL_MIN_WIDTH, maxf(viewport_size.x - panel_margin_size * 2.0, MIN_PANEL_WIDTH)),
		0.0
	)
	panel_margin.add_theme_constant_override("margin_left", panel_margin_size)
	panel_margin.add_theme_constant_override("margin_top", panel_margin_size)
	panel_margin.add_theme_constant_override("margin_right", panel_margin_size)
	panel_margin.add_theme_constant_override("margin_bottom", panel_margin_size)
	options_box.add_theme_constant_override("separation", section_separation)
	title_label.add_theme_font_size_override("font_size", COMPACT_TITLE_FONT_SIZE if use_compact_layout else DEFAULT_TITLE_FONT_SIZE)
	stats_label.add_theme_font_size_override("font_size", COMPACT_STATS_FONT_SIZE if use_compact_layout else DEFAULT_STATS_FONT_SIZE)
	stats_label.add_theme_color_override("font_color", SUMMARY_TEXT_COLOR)
	next_round_label.add_theme_font_size_override("font_size", COMPACT_NEXT_ROUND_FONT_SIZE if use_compact_layout else DEFAULT_NEXT_ROUND_FONT_SIZE)
	next_round_label.add_theme_color_override("font_color", NEXT_ROUND_TEXT_COLOR)
	continue_label.add_theme_font_size_override("font_size", COMPACT_CONTINUE_FONT_SIZE if use_compact_layout else DEFAULT_CONTINUE_FONT_SIZE)
	continue_label.add_theme_color_override("font_color", CONTINUE_TEXT_COLOR)

	for positive_button in _positive_offer_buttons:
		positive_button.custom_minimum_size = Vector2(0.0, action_button_height)
		positive_button.add_theme_font_size_override("font_size", COMPACT_ACTION_FONT_SIZE if use_compact_layout else DEFAULT_ACTION_FONT_SIZE)

	if _pending_items_label:
		_pending_items_label.add_theme_font_size_override("font_size", COMPACT_PENDING_FONT_SIZE if use_compact_layout else DEFAULT_PENDING_FONT_SIZE)
		_pending_items_label.add_theme_color_override("font_color", Color(0.87, 1.0, 0.86, 1.0))

	if _hazard_draft_section:
		_hazard_draft_section.add_theme_constant_override(
			"separation",
			COMPACT_HAZARD_SECTION_SEPARATION if use_compact_layout else DEFAULT_HAZARD_SECTION_SEPARATION
		)
	if _hazard_draft_title:
		_hazard_draft_title.add_theme_font_size_override(
			"font_size",
			COMPACT_HAZARD_TITLE_FONT_SIZE if use_compact_layout else DEFAULT_HAZARD_TITLE_FONT_SIZE
		)
		_hazard_draft_title.add_theme_color_override("font_color", SECTION_TEXT_COLOR)
	for hazard_button in _hazard_draft_buttons:
		hazard_button.custom_minimum_size = Vector2(0.0, hazard_button_height)
		hazard_button.add_theme_font_size_override(
			"font_size",
			COMPACT_HAZARD_BUTTON_FONT_SIZE if use_compact_layout else DEFAULT_HAZARD_BUTTON_FONT_SIZE
		)

	if _subtitle_label:
		_subtitle_label.add_theme_font_size_override(
			"font_size",
			COMPACT_SUBTITLE_FONT_SIZE if use_compact_layout else DEFAULT_SUBTITLE_FONT_SIZE
		)

	if _shop_section_label:
		_shop_section_label.add_theme_font_size_override(
			"font_size",
			COMPACT_SECTION_TITLE_FONT_SIZE if use_compact_layout else DEFAULT_SECTION_TITLE_FONT_SIZE
		)


func _on_viewport_size_changed() -> void:
	_apply_responsive_layout()


func _reorder_dynamic_controls() -> void:
	var next_index: int = _shop_section_label.get_index() + 1 if _shop_section_label else buy_time_button.get_index()
	for positive_button in _positive_offer_buttons:
		options_box.move_child(positive_button, next_index)
		next_index += 1
	if _queued_panel:
		options_box.move_child(_queued_panel, next_index)
		next_index += 1
	if _hazard_draft_section:
		options_box.move_child(_hazard_draft_section, next_index)
		next_index += 1
	if _footer_panel:
		options_box.move_child(_footer_panel, next_index)


func _reorder_static_sections() -> void:
	var next_index: int = title_label.get_index() + 1
	if _subtitle_label:
		options_box.move_child(_subtitle_label, next_index)
		next_index += 1
	if _summary_panel:
		options_box.move_child(_summary_panel, next_index)
		next_index += 1
	if _shop_section_label:
		options_box.move_child(_shop_section_label, next_index)

	_reorder_dynamic_controls()


func _move_control(control: Control, new_parent: Node) -> void:
	var old_parent: Node = control.get_parent()
	if old_parent == new_parent:
		return
	if old_parent != null:
		old_parent.remove_child(control)
	new_parent.add_child(control)


func _create_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.shadow_color = PANEL_SHADOW_COLOR
	style.shadow_size = 18
	return style


func _apply_action_button_theme(button: Button, accent_color: Color, is_enabled: bool) -> void:
	var normal_color: Color = accent_color.darkened(0.7)
	var hover_color: Color = accent_color.darkened(0.62)
	var pressed_color: Color = accent_color.darkened(0.76)
	var disabled_color: Color = Color(0.15, 0.17, 0.21, 0.92)

	button.add_theme_stylebox_override("normal", _create_panel_style(normal_color, accent_color))
	button.add_theme_stylebox_override("hover", _create_panel_style(hover_color, accent_color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _create_panel_style(pressed_color, accent_color))
	button.add_theme_stylebox_override("disabled", _create_panel_style(disabled_color, Color(0.33, 0.37, 0.45, 0.4)))
	button.add_theme_stylebox_override("focus", _create_panel_style(normal_color, accent_color))
	button.add_theme_color_override("font_color", PRIMARY_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", PRIMARY_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", PRIMARY_TEXT_COLOR)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(0.56, 0.61, 0.68, 1.0) if not is_enabled else PRIMARY_TEXT_COLOR
	)


func _apply_hazard_button_theme(button: Button, is_selected: bool) -> void:
	var border_color: Color = HAZARD_ACCENT if is_selected else Color(0.4, 0.45, 0.55, 0.58)
	var base_color: Color = Color(0.18, 0.12, 0.11, 0.96) if is_selected else Color(0.13, 0.15, 0.19, 0.96)
	var hover_color: Color = base_color.lightened(0.05)

	button.add_theme_stylebox_override("normal", _create_panel_style(base_color, border_color))
	button.add_theme_stylebox_override("hover", _create_panel_style(hover_color, border_color))
	button.add_theme_stylebox_override("pressed", _create_panel_style(base_color.darkened(0.05), border_color))
	button.add_theme_stylebox_override("focus", _create_panel_style(base_color, border_color))
	button.add_theme_color_override("font_color", PRIMARY_TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", PRIMARY_TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", PRIMARY_TEXT_COLOR)


func _refresh_display() -> void:
	if not is_node_ready():
		return

	var completed_laps: int = _lap_tracker.completed_laps if _lap_tracker else 0
	var round_number: int = _run_state.round_number if _run_state else 0
	var multiplier: int = _run_state.current_multiplier if _run_state else 1
	var round_earnings: int = _run_state.round_earnings if _run_state else 0
	var currency: int = _run_state.currency if _run_state else 0
	var next_round_time: float = _run_state.starting_round_time if _run_state else 0.0

	stats_label.text = "Round %d\nLaps cleared %d\nEnding multi x%d\nRound cash +$%d\nTotal bank $%d" % [
		round_number,
		completed_laps,
		multiplier,
		round_earnings,
		currency,
	]
	next_round_label.text = "Starting timer %s" % _format_round_time(next_round_time)

	for offer_index in range(_positive_offer_buttons.size()):
		var offer_button: Button = _positive_offer_buttons[offer_index]
		var has_offer: bool = offer_index < _positive_offers.size()
		offer_button.visible = has_offer
		if not has_offer:
			continue

		var positive_type: int = _positive_offers[offer_index]
		var cost: int = _get_positive_offer_cost(positive_type)
		var shortcut: String = POSITIVE_SHORTCUTS[offer_index]
		var is_disabled: bool = _run_state == null or cost <= 0 or currency < cost
		var button_text: String = "[%s] %s\n%s\nCost $%d" % [
			shortcut,
			PositiveTypeRegistry.get_display_name(positive_type),
			PositiveTypeRegistry.get_description(positive_type),
			cost,
		]
		if positive_type == PositiveTypeRegistry.Type.TIME_BANK and _run_state and _run_state.time_bank_cost_increase > 0:
			button_text += "\nNext buy +$%d" % _run_state.time_bank_cost_increase

		offer_button.text = button_text
		offer_button.disabled = is_disabled
		_apply_action_button_theme(
			offer_button,
			_get_positive_accent(PositiveTypeRegistry.get_category(positive_type)),
			not is_disabled
		)

	if _pending_items_label:
		var pending_parts: Array[String] = []
		var counts_by_type: Dictionary[int, int] = {}
		for positive_type in _pending_positive_types:
			counts_by_type[positive_type] = counts_by_type.get(positive_type, 0) + 1

		var pending_types: Array = counts_by_type.keys()
		pending_types.sort_custom(func(a: int, b: int) -> bool:
			return PositiveTypeRegistry.get_display_name(a) < PositiveTypeRegistry.get_display_name(b))
		for positive_type in pending_types:
			var count: int = counts_by_type[positive_type]
			pending_parts.append("%d %s%s" % [
				count,
				PositiveTypeRegistry.get_display_name(positive_type),
				"" if count == 1 else "s",
			])

		_pending_items_label.text = "Queued for placement: %s" % ", ".join(pending_parts)
		if _queued_panel:
			_queued_panel.visible = not pending_parts.is_empty()
		else:
			_pending_items_label.visible = not pending_parts.is_empty()

	if _hazard_draft_section:
		_hazard_draft_section.visible = _requires_hazard_draft
		if _hazard_draft_title:
			_hazard_draft_title.text = "Draft the Lesser Evil"
		for button_index in range(_hazard_draft_buttons.size()):
			var hazard_button: Button = _hazard_draft_buttons[button_index]
			var has_option: bool = button_index < _hazard_draft_options.size()
			hazard_button.visible = has_option
			if not has_option:
				continue

			var hazard_type: int = _hazard_draft_options[button_index]
			var is_selected: bool = hazard_type == _selected_hazard_type
			var button_text: String = "[%d] %s%s\n%s" % [
				button_index + 1,
				HazardTypeRegistry.get_display_name(hazard_type),
				" (Selected)" if is_selected else "",
				HazardTypeRegistry.get_description(hazard_type),
			]
			hazard_button.text = button_text
			_apply_hazard_button_theme(hazard_button, is_selected)

	continue_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	continue_label.add_theme_color_override("font_color", CONTINUE_TEXT_COLOR)
	continue_label.text = "Space / Enter to start the next round"
	if _requires_hazard_draft and _selected_hazard_type == HazardTypeRegistry.NONE:
		continue_label.text = "Pick a hazard with %s before continuing" % _format_hazard_shortcuts()
		continue_label.add_theme_color_override("font_color", BLOCKED_TEXT_COLOR)
	elif not _pending_positive_types.is_empty():
		continue_label.text = "Space / Enter to place queued positives"
	elif _requires_hazard_draft:
		continue_label.text = "Space / Enter to place the drafted hazard"


func _format_round_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var total_seconds: int = int(safe_seconds)
	var minutes: int = int(total_seconds / 60.0)
	var whole_seconds: int = total_seconds % 60
	var tenths: int = int(floor(fposmod(safe_seconds, 1.0) * 10.0))
	return "%d:%02d.%01d" % [minutes, whole_seconds, tenths]


func _request_positive_offer(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _positive_offers.size():
		return
	positive_offer_requested.emit(offer_index)


func _get_positive_offer_cost(positive_type: int) -> int:
	if positive_type == PositiveTypeRegistry.Type.TIME_BANK and _run_state:
		return _run_state.current_time_bank_cost
	return PositiveTypeRegistry.get_base_cost(positive_type)


func _get_positive_accent(category: int) -> Color:
	match category:
		PositiveTypeRegistry.Category.UTILITY:
			return UTILITY_ACCENT
		PositiveTypeRegistry.Category.GREED:
			return GREED_ACCENT
		PositiveTypeRegistry.Category.HANDLING:
			return HANDLING_ACCENT
		_:
			return UTILITY_ACCENT


func _on_positive_offer_button_pressed(offer_index: int) -> void:
	_request_positive_offer(offer_index)


func _on_hazard_draft_button_pressed(button_index: int) -> void:
	_select_hazard_draft_index(button_index)


func _select_hazard_draft_index(button_index: int) -> void:
	if not _requires_hazard_draft:
		return
	if button_index < 0 or button_index >= _hazard_draft_options.size():
		return

	_selected_hazard_type = _hazard_draft_options[button_index]
	hazard_drafted.emit(_selected_hazard_type)
	_refresh_display()


func _can_continue() -> bool:
	return not _requires_hazard_draft or _selected_hazard_type != HazardTypeRegistry.NONE


func _format_hazard_shortcuts() -> String:
	var shortcuts: Array[String] = []
	for option_index in range(_hazard_draft_options.size()):
		shortcuts.append(str(option_index + 1))
	return " / ".join(shortcuts)
