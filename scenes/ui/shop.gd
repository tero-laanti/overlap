extends CanvasLayer
## Shop UI. Presentation and purchase intents only: reads Bank's catalog
## and prices, calls Bank.try_buy_*. All pricing and effects live in Bank
## and the def resources. Toggled with the toggle_shop action.

var _upgrade_rows := {}
var _gate_rows := {}
var _ghost_label: Label
var _ghost_button: Button

@onready var _rows: VBoxContainer = %Rows
@onready var _milestone_label: Label = %Milestone


func _ready() -> void:
	visible = false
	Events.currency_changed.connect(func(_amount: float) -> void: _refresh())
	Events.upgrade_purchased.connect(func(_id: String, _level: int) -> void: _refresh())
	Events.ghost_hired.connect(func(_count: int) -> void: _refresh())
	Events.gate_purchased.connect(func(_id: String) -> void: _refresh())
	_build_rows()
	# Bank learns the active network in Main._ready, after this ready runs.
	_build_gate_rows.call_deferred()
	_refresh()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_shop"):
		visible = not visible
		if visible:
			_refresh()


func _build_rows() -> void:
	for def in Bank.CATALOG.upgrades:
		var row := _make_row("%s" % def.display_name)
		row.button.pressed.connect(Bank.try_buy_upgrade.bind(def.id))
		_upgrade_rows[def.id] = row
	var ghost_row := _make_row("Hire Ghost")
	ghost_row.button.pressed.connect(Bank.try_buy_ghost_slot)
	_ghost_label = ghost_row.label
	_ghost_button = ghost_row.button


func _build_gate_rows() -> void:
	for gate in Bank.unpurchased_gates():
		var row := _make_row(gate.display_name)
		row.button.pressed.connect(Bank.try_buy_gate.bind(gate.id))
		_gate_rows[gate.id] = row
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
		var row: Dictionary = _gate_rows[id]
		var button := row.button as Button
		if Bank.is_gate_purchased(id):
			button.text = "OPEN"
			button.disabled = true
		else:
			button.text = "$ %d" % int(Bank.gate_cost(id))
			button.disabled = Bank.currency < Bank.gate_cost(id)
	_ghost_label.text = "Hire Ghost  ×%d" % Bank.ghost_slots
	_ghost_button.text = "$ %d" % int(Bank.ghost_slot_cost())
	_ghost_button.disabled = Bank.currency < Bank.ghost_slot_cost()
	_milestone_label.text = _milestone_text()


func _milestone_text() -> String:
	var passed := 0
	for count: int in Bank.ECONOMY.milestone_counts:
		if Bank.ghost_slots < count:
			var bonus := roundi(pow(Bank.ECONOMY.milestone_multiplier, passed + 1))
			return "Fleet bonus x%d at %d ghosts (%d/%d)" % [
				bonus, count, Bank.ghost_slots, count]
		passed += 1
	return "All fleet bonuses active"
