class_name RoundEndScreen
extends CanvasLayer

const HazardTypeRegistry := preload("res://race/hazard_type.gd")

signal buy_time_requested
signal buy_boost_pad_requested
signal hazard_drafted(hazard_type: int)
signal continue_requested

@export var run_state_path: NodePath
@export var lap_tracker_path: NodePath

@onready var options_box: VBoxContainer = $Center/Panel/Margin/VBox
@onready var stats_label: Label = $Center/Panel/Margin/VBox/StatsLabel
@onready var next_round_label: Label = $Center/Panel/Margin/VBox/NextRoundLabel
@onready var buy_time_button: Button = $Center/Panel/Margin/VBox/BuyTimeButton
@onready var continue_label: Label = $Center/Panel/Margin/VBox/ContinueLabel

var _run_state: RunState = null
var _lap_tracker: LapTracker = null
var _buy_time_cost: int = 0
var _buy_time_seconds: float = 0.0
var _buy_boost_pad_cost: int = 0
var _pending_start_time_bonus: float = 0.0
var _pending_boost_pad_count: int = 0
var _buy_boost_pad_button: Button = null
var _pending_items_label: Label = null
var _hazard_draft_section: VBoxContainer = null
var _hazard_draft_title: Label = null
var _hazard_draft_buttons: Array[Button] = []
var _hazard_draft_options: Array[int] = []
var _selected_hazard_type: int = HazardTypeRegistry.NONE
var _requires_hazard_draft: bool = false


func _ready() -> void:
	visible = false
	_ensure_dynamic_controls()
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

	if not _lap_tracker:
		push_warning("RoundEndScreen could not find the lap tracker.")

	if not buy_time_button.pressed.is_connected(_on_buy_time_button_pressed):
		buy_time_button.pressed.connect(_on_buy_time_button_pressed)
	if _buy_boost_pad_button and not _buy_boost_pad_button.pressed.is_connected(_on_buy_boost_pad_button_pressed):
		_buy_boost_pad_button.pressed.connect(_on_buy_boost_pad_button_pressed)

	_refresh_display()


func configure_buy_time_option(cost: int, seconds: float) -> void:
	_buy_time_cost = maxi(cost, 0)
	_buy_time_seconds = maxf(seconds, 0.0)
	_refresh_display()


func configure_buy_boost_pad_option(cost: int) -> void:
	_buy_boost_pad_cost = maxi(cost, 0)
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


func set_pending_start_time_bonus(seconds: float) -> void:
	_pending_start_time_bonus = maxf(seconds, 0.0)
	_refresh_display()


func set_pending_boost_pad_count(count: int) -> void:
	_pending_boost_pad_count = maxi(count, 0)
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
	elif event.is_action_pressed("buy_time"):
		get_viewport().set_input_as_handled()
		buy_time_requested.emit()
	elif event.is_action_pressed("buy_boost_pad"):
		get_viewport().set_input_as_handled()
		buy_boost_pad_requested.emit()
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


func _on_buy_time_button_pressed() -> void:
	buy_time_requested.emit()


func _on_buy_boost_pad_button_pressed() -> void:
	buy_boost_pad_requested.emit()


func _ensure_dynamic_controls() -> void:
	if _buy_boost_pad_button == null:
		_buy_boost_pad_button = Button.new()
		_buy_boost_pad_button.name = "BuyBoostPadButton"
		_buy_boost_pad_button.custom_minimum_size = Vector2(0.0, 54.0)
		_buy_boost_pad_button.add_theme_font_size_override("font_size", 22)
		_buy_boost_pad_button.focus_mode = Control.FOCUS_NONE
		options_box.add_child(_buy_boost_pad_button)
		options_box.move_child(_buy_boost_pad_button, continue_label.get_index())

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
		_hazard_draft_section.add_theme_constant_override("separation", 8)
		options_box.add_child(_hazard_draft_section)
		options_box.move_child(_hazard_draft_section, continue_label.get_index())

		_hazard_draft_title = Label.new()
		_hazard_draft_title.name = "HazardDraftTitle"
		_hazard_draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hazard_draft_title.add_theme_font_size_override("font_size", 24)
		_hazard_draft_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.72, 1.0))
		_hazard_draft_title.text = "Draft a Hazard"
		_hazard_draft_section.add_child(_hazard_draft_title)

		for index in range(3):
			var hazard_button: Button = Button.new()
			hazard_button.name = "HazardDraftButton%d" % (index + 1)
			hazard_button.custom_minimum_size = Vector2(0.0, 70.0)
			hazard_button.focus_mode = Control.FOCUS_NONE
			if not hazard_button.pressed.is_connected(_on_hazard_draft_button_pressed.bind(index)):
				hazard_button.pressed.connect(_on_hazard_draft_button_pressed.bind(index))
			_hazard_draft_section.add_child(hazard_button)
			_hazard_draft_buttons.append(hazard_button)

	_reorder_dynamic_controls()


func _reorder_dynamic_controls() -> void:
	var next_index: int = buy_time_button.get_index() + 1
	if _buy_boost_pad_button:
		options_box.move_child(_buy_boost_pad_button, next_index)
		next_index += 1
	if _hazard_draft_section:
		options_box.move_child(_hazard_draft_section, next_index)
		next_index += 1
	if _pending_items_label:
		options_box.move_child(_pending_items_label, next_index)


func _refresh_display() -> void:
	if not is_node_ready():
		return

	var completed_laps: int = _lap_tracker.completed_laps if _lap_tracker else 0
	var round_number: int = _run_state.round_number if _run_state else 0
	var multiplier: int = _run_state.current_multiplier if _run_state else 1
	var round_earnings: int = _run_state.round_earnings if _run_state else 0
	var currency: int = _run_state.currency if _run_state else 0
	var next_round_time: float = (
		_run_state.starting_round_time + _pending_start_time_bonus if _run_state else _pending_start_time_bonus
	)

	stats_label.text = "Round %d\nLaps %d\nEnding Multiplier x%d\nRound Cash $%d\nTotal Cash $%d" % [
		round_number,
		completed_laps,
		multiplier,
		round_earnings,
		currency,
	]
	next_round_label.text = "Next Round Starts With %s" % _format_round_time(next_round_time)
	if _pending_start_time_bonus > 0.0:
		next_round_label.text += " (%s bonus)" % _format_bonus_seconds(_pending_start_time_bonus)

	buy_time_button.text = "[B] Buy +%s Next Round ($%d)" % [
		_format_bonus_seconds(_buy_time_seconds),
		_buy_time_cost,
	]
	buy_time_button.disabled = (
		_run_state == null
		or _buy_time_cost <= 0
		or _buy_time_seconds <= 0.0
		or currency < _buy_time_cost
	)

	if _buy_boost_pad_button:
		_buy_boost_pad_button.text = "[P] Buy Boost Pad ($%d)" % _buy_boost_pad_cost
		_buy_boost_pad_button.disabled = (
			_run_state == null
			or _buy_boost_pad_cost <= 0
			or currency < _buy_boost_pad_cost
		)

	if _pending_items_label:
		var pending_parts: Array[String] = []
		if _pending_start_time_bonus > 0.0:
			pending_parts.append("+%s start time" % _format_bonus_seconds(_pending_start_time_bonus))
		if _pending_boost_pad_count > 0:
			pending_parts.append("%d Boost Pad%s" % [
				_pending_boost_pad_count,
				"" if _pending_boost_pad_count == 1 else "s",
			])

		_pending_items_label.visible = not pending_parts.is_empty()
		_pending_items_label.text = "Queued: %s" % ", ".join(pending_parts)

	if _hazard_draft_section:
		_hazard_draft_section.visible = _requires_hazard_draft
		if _hazard_draft_title:
			_hazard_draft_title.text = "Draft a Hazard"
		for button_index in range(_hazard_draft_buttons.size()):
			var hazard_button: Button = _hazard_draft_buttons[button_index]
			var has_option: bool = button_index < _hazard_draft_options.size()
			hazard_button.visible = has_option
			if not has_option:
				continue

			var hazard_type: int = _hazard_draft_options[button_index]
			var button_text: String = "[%d] %s\n%s" % [
				button_index + 1,
				HazardTypeRegistry.get_display_name(hazard_type),
				HazardTypeRegistry.get_description(hazard_type),
			]
			if hazard_type == _selected_hazard_type:
				button_text += "\nSelected"
				hazard_button.modulate = Color(1.0, 0.92, 0.78, 1.0)
			else:
				hazard_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

			hazard_button.text = button_text

	continue_label.modulate = Color(0.84, 0.86, 0.9, 1.0)
	continue_label.text = "Space / Enter to continue"
	if _requires_hazard_draft and _selected_hazard_type == HazardTypeRegistry.NONE:
		continue_label.text = "Pick a hazard with %s before continuing" % _format_hazard_shortcuts()
		continue_label.modulate = Color(1.0, 0.72, 0.68, 1.0)
	elif _pending_boost_pad_count > 0:
		continue_label.text = "Space / Enter to place before the next round"
	elif _requires_hazard_draft:
		continue_label.text = "Space / Enter to place the drafted hazard"


func _format_bonus_seconds(seconds: float) -> String:
	if is_zero_approx(fposmod(seconds, 1.0)):
		return "%ds" % int(seconds)
	return "%.1fs" % seconds


func _format_round_time(seconds: float) -> String:
	var safe_seconds: float = maxf(seconds, 0.0)
	var total_seconds: int = int(safe_seconds)
	var minutes: int = total_seconds / 60
	var whole_seconds: int = total_seconds % 60
	var tenths: int = int(floor(fposmod(safe_seconds, 1.0) * 10.0))
	return "%d:%02d.%01d" % [minutes, whole_seconds, tenths]


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
