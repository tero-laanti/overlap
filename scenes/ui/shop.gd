extends CanvasLayer
## Shop UI. Presentation and purchase intents only: reads Bank's catalog
## and prices, calls Bank.try_buy_*. All pricing and effects live in Bank
## and the def resources; which rows exist comes from ShopPacing — the
## GARAGE grows as the run progresses. Toggled with the toggle_shop action.

const ShopPacingScript = preload("res://scenes/ui/shop_pacing.gd")
const CarScript = preload("res://scenes/car/car.gd")

var _car: CarScript
var _garage_zone: Node2D
var _upgrade_rows := {}
var _gate_rows := {}
var _medal_rows := {}
var _ghost_label: Label
var _ghost_button: Button

@onready var _rows: VBoxContainer = %Rows
@onready var _milestone_label: Label = %Milestone


func _ready() -> void:
	visible = false
	Events.currency_changed.connect(func(_amount: float) -> void: _refresh())
	Events.upgrade_purchased.connect(func(_id: String, _level: int) -> void: _rebuild())
	# Rebuild, not refresh: the first hire (rival beaten) reveals the row.
	Events.ghost_hired.connect(func(_count: int) -> void: _rebuild())
	Events.gate_purchased.connect(func(_id: String) -> void: _rebuild())
	Events.route_discovered.connect(func(_id: String, _name: String) -> void: _rebuild())
	Events.medal_unlocked.connect(func(_id: String) -> void: _rebuild())
	# Bank learns the active network in Main._ready, after this ready runs.
	_rebuild.call_deferred()


## Shopping happens AT the garage: TAB only works parked by the
## building, and driving off closes the menu.
func _process(_delta: float) -> void:
	if visible and not _at_garage():
		visible = false
		return
	if Input.is_action_just_pressed("toggle_shop") and _at_garage():
		visible = not visible
		if visible:
			_refresh()


func _at_garage() -> bool:
	if not Bank.garage_unlocked:
		return false
	if _car == null:
		_car = get_tree().get_first_node_in_group("player_car")
	if _garage_zone == null:
		_garage_zone = get_tree().get_first_node_in_group("garage_zone")
	if _car == null or _garage_zone == null:
		return false
	return _garage_zone.contains(_car.global_position)


func _rebuild() -> void:
	if not is_node_ready():
		return
	for child in _rows.get_children():
		child.queue_free()
	_upgrade_rows.clear()
	_gate_rows.clear()
	_medal_rows.clear()
	for def in ShopPacingScript.visible_upgrades(Bank):
		var row := _make_row("%s" % def.display_name)
		row.button.pressed.connect(Bank.try_buy_upgrade.bind(def.id))
		_upgrade_rows[def.id] = row
	# Ghost slots stay off the shelf until the rival is beaten — the win
	# hires ghost #1; only then do further slots go on sale.
	_ghost_label = null
	_ghost_button = null
	if Bank.ghost_slots >= 1:
		var ghost_row := _make_row("Hire Ghost")
		ghost_row.button.pressed.connect(Bank.try_buy_ghost_slot)
		_ghost_label = ghost_row.label
		_ghost_button = ghost_row.button
	var gate := ShopPacingScript.next_gate(Bank)
	if gate != null:
		var row := _make_row(gate.display_name)
		row.button.pressed.connect(Bank.try_buy_gate.bind(gate.id))
		_gate_rows[gate.id] = row
	for route in ShopPacingScript.medal_offers(Bank):
		var row := _make_row("Mastery: %s" % route.display_name)
		row.button.pressed.connect(Bank.try_buy_medal_unlock.bind(route.id))
		_medal_rows[route.id] = row
	if OS.is_debug_build():
		var reset_row := _make_row("DEBUG · wipe save")
		(reset_row.button as Button).text = "RESET"
		reset_row.button.pressed.connect(func() -> void:
			Bank.reset_profile()
			get_tree().reload_current_scene.call_deferred())
	_refresh()


func _make_row(title: String) -> Dictionary:
	var box := HBoxContainer.new()
	box.custom_minimum_size = Vector2(280, 40)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	box.add_child(label)
	var button := Button.new()
	button.custom_minimum_size = Vector2(90, 0)
	# The game never pauses: a focused button would fire on Space (drift)
	# and arrow keys (steering double as ui_* focus moves) while driving.
	button.focus_mode = Control.FOCUS_NONE
	box.add_child(button)
	_rows.add_child(box)
	return {"label": label, "button": button}


func _refresh() -> void:
	if not is_node_ready():
		return
	for id: String in _upgrade_rows:
		var def := Bank.CATALOG.find(id)
		var row: Dictionary = _upgrade_rows[id]
		var level := Bank.upgrade_level(id)
		var maxed := level >= def.max_level
		(row.label as Label).text = "%s  Lv %d" % [def.display_name, level]
		var button := row.button as Button
		button.text = "MAX" if maxed else "$ %d" % int(Bank.upgrade_cost(id))
		button.disabled = maxed or Bank.currency < Bank.upgrade_cost(id)
	for id: String in _gate_rows:
		var button: Button = _gate_rows[id].button
		button.text = "$ %d" % int(Bank.gate_cost(id))
		button.disabled = Bank.currency < Bank.gate_cost(id)
	for id: String in _medal_rows:
		var button: Button = _medal_rows[id].button
		button.text = "$ %d" % int(Bank.medal_unlock_cost(id))
		button.disabled = Bank.currency < Bank.medal_unlock_cost(id)
	if _ghost_label != null:
		_ghost_label.text = "Hire Ghost  ×%d" % Bank.ghost_slots
		_ghost_button.text = "$ %d" % int(Bank.ghost_slot_cost())
		_ghost_button.disabled = Bank.currency < Bank.ghost_slot_cost()
	_milestone_label.text = _milestone_text()


func _milestone_text() -> String:
	if Bank.ghost_slots < 1:
		return "Ghost bays locked — beat the rivals"
	var passed := 0
	for count: int in Bank.ECONOMY.milestone_counts:
		if Bank.ghost_slots < count:
			var bonus := roundi(pow(Bank.ECONOMY.milestone_multiplier, passed + 1))
			return "Fleet bonus x%d at %d ghosts (%d/%d)" % [
				bonus, count, Bank.ghost_slots, count]
		passed += 1
	return "All fleet bonuses active"
