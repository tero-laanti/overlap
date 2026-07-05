extends CanvasLayer
## Route collection log. Presentation only, reads Bank: a discovered
## route gets a full card (name, PB, fleet income); a hinted route (all
## its gates owned, never driven) shows a silhouette and its clue; the
## rest exist only in the X/N counter. Toggled with toggle_routes.

const HudScript = preload("res://scenes/ui/hud.gd")

@onready var _counter: Label = %Counter
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	visible = false
	Events.route_discovered.connect(func(_id: String, _name: String) -> void: _refresh())
	Events.best_lap_recorded.connect(func(_id: String, _rec: Resource) -> void: _refresh())
	Events.ghost_hired.connect(func(_count: int) -> void: _refresh())
	Events.gate_purchased.connect(func(_id: String) -> void: _refresh())
	# Bank learns the active network in Main._ready, after this ready runs.
	_refresh.call_deferred()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_routes"):
		visible = not visible
		if visible:
			_refresh()


## [title, info] pairs plus the counter — also what the DevProbe prints.
func entries_text() -> Array[String]:
	var routes := Bank.authored_routes()
	var discovered := 0
	for route in routes:
		if route.id in Bank.discovered_routes:
			discovered += 1
	var lines: Array[String] = ["%d/%d discovered" % [discovered, routes.size()]]
	for route in routes:
		if route.id in Bank.discovered_routes:
			lines.append("%s — PB %s  +%.1f/s" % [
				route.display_name,
				HudScript.format_time(Bank.route_pb(route.id)),
				Bank.route_income_per_second(route.id),
			])
		elif Bank.is_route_hinted(route.id):
			lines.append("??? — %s" % route.clue)
	return lines


func _refresh() -> void:
	if not is_node_ready():
		return
	for child in _rows.get_children():
		child.queue_free()
	var lines := entries_text()
	_counter.text = lines[0]
	for i in range(1, lines.size()):
		var label := Label.new()
		label.text = lines[i]
		label.add_theme_font_size_override("font_size", 16)
		if lines[i].begins_with("???"):
			label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.68))
		_rows.add_child(label)
