extends CanvasLayer
## Race HUD. Presentation only: reads RaceState and the car each frame,
## reacts to track/Events signals. No math beyond formatting. Main injects
## references and wires track signals.

const PIP_EMPTY := "○"
const PIP_FULL := "●"
const TOAST_SECONDS := 2.2
const CarScript = preload("res://scenes/car/car.gd")
const RaceStateScript = preload("res://scenes/main/race_state.gd")
const ShopPacingScript = preload("res://scenes/ui/shop_pacing.gd")

var race_state: RaceStateScript
var car: CarScript

var _garage_zone: Node2D
var _rival_racer: Node2D
var _pips_filled := 0
var _pips_total := 2
var _suppress_lap_toast := false
var _toast_tween: Tween

@onready var _current_label: Label = %CurrentLap
@onready var _best_label: Label = %BestLap
@onready var _last_label: Label = %LastLap
@onready var _pips_label: Label = %CheckpointPips
@onready var _speed_label: Label = %Speed
@onready var _toast_label: Label = %Toast
@onready var _money_label: Label = %Money
@onready var _income_label: Label = %IncomeRate
@onready var _next_label: Label = %NextHint
@onready var _shop_hint: Label = %ShopHint


func _ready() -> void:
	Events.lap_completed.connect(_on_lap_completed)
	Events.offline_earnings_granted.connect(_on_offline_earnings_granted)
	Events.route_discovered.connect(_on_route_discovered)
	Events.car_reset_to_road.connect(func() -> void:
		_show_toast("SPLASH — lap void", false))
	Events.secret_unlocked.connect(func(_id: String) -> void:
		_show_toast("A hidden road reveals itself…", true))
	Events.rival_race_finished.connect(_on_rival_race_finished)
	Events.garage_unlocked.connect(func() -> void:
		_show_toast("GARAGE OPEN — pull in and press TAB", true))
	# ghost_hired fires only once at slot 1: the final rival's reward.
	Events.ghost_hired.connect(func(count: int) -> void:
		if count == 1:
			_show_toast("GHOSTS UNLOCKED — your best lap now drives itself", true)
			_suppress_lap_toast = true)
	_toast_label.modulate.a = 0.0
	_refresh_pips()
	# Cold open on a fresh profile: the game starts as a race.
	if Bank.ghost_slots == 0:
		_show_toast("%s wants a race — beat their lap" % _rival_name(), true)


func _process(_delta: float) -> void:
	if race_state != null:
		_current_label.text = format_time(race_state.current_lap_time)
		_best_label.text = "BEST %s" % format_time(race_state.best_lap_time)
		_last_label.text = "LAST %s" % format_time(race_state.last_lap_time)
	if car != null:
		_speed_label.text = "%d" % int(car.velocity.length() / 10.0)
	_money_label.text = "$ %s" % format_money(Bank.currency)
	_income_label.text = "+%.1f/s" % Bank.income_per_second()
	_next_label.text = _next_purchase_hint()
	_shop_hint.visible = _at_garage()


func _at_garage() -> bool:
	if not Bank.garage_unlocked or car == null:
		return false
	if _garage_zone == null:
		_garage_zone = get_tree().get_first_node_in_group("garage_zone")
	return _garage_zone != null and _garage_zone.contains(car.global_position)


## One line of direction: onboarding objectives first, then the cheapest
## offer currently in the garage (same pacing rules the shop renders).
## Read-only against Bank — no purchase logic here.
func _next_purchase_hint() -> String:
	if not Bank.garage_unlocked:
		return "WASD drive · SPACE drift — beat %s" % _rival_name()
	var next_name := ""
	var next_cost := INF
	# Ghost slots are rival-gated: no hire hint until ghost #1 exists.
	if Bank.ghost_slots >= 1:
		next_name = "Hire Ghost"
		next_cost = Bank.ghost_slot_cost()
	for def in ShopPacingScript.visible_upgrades(Bank):
		if Bank.upgrade_level(def.id) >= def.max_level:
			continue
		var cost := Bank.upgrade_cost(def.id)
		if cost < next_cost:
			next_cost = cost
			next_name = def.display_name
	var gate := ShopPacingScript.next_gate(Bank)
	if gate != null and gate.price < next_cost:
		next_cost = gate.price
		next_name = gate.display_name
	for route in ShopPacingScript.medal_offers(Bank):
		if route.medal_unlock_cost < next_cost:
			next_cost = route.medal_unlock_cost
			next_name = "Mastery: %s" % route.display_name
	if next_name != "" and Bank.currency >= next_cost:
		return "garage: %s ready — pull in!" % next_name
	var income := Bank.income_per_second()
	if income <= 0.0:
		# Rival era: earnings come from laps, the objective is the race.
		if Bank.ghost_slots == 0:
			return "beat %s — ghosts await" % _rival_name()
		return ""
	var eta := ceili((next_cost - Bank.currency) / income)
	return "next: %s in ~%ds" % [next_name, eta]


func on_lap_started() -> void:
	_pips_filled = 0
	_refresh_pips()


func on_checkpoint_crossed(index: int, total: int) -> void:
	_pips_total = total
	_pips_filled = index + 1
	_refresh_pips()


func _on_lap_completed(_route_id: String, lap_time: float, is_best: bool) -> void:
	_pips_filled = 0
	_refresh_pips()
	if _suppress_lap_toast:
		_suppress_lap_toast = false
		return
	_show_toast(
		"NEW BEST  %s" % format_time(lap_time) if is_best
		else "LAP  %s" % format_time(lap_time),
		is_best,
	)


## Discovery outranks the routine lap toast that lands the same instant.
func _on_route_discovered(_route_id: String, display_name: String) -> void:
	_show_toast("NEW ROUTE  %s" % display_name, true)
	_suppress_lap_toast = true


## Race results land mid-lap-completion and outrank the lap toast.
func _on_rival_race_finished(_rival_id: String, display_name: String,
		player_time: float, rival_time: float, won: bool) -> void:
	_suppress_lap_toast = true
	if won:
		# Fires before Bank records the win — show the multiplier this
		# win is about to set.
		_show_toast("%s BEATEN by %.2fs — payouts ×%d" % [
			display_name, rival_time - player_time,
			int(Bank.rival_multiplier() * Bank.ECONOMY.rival_beaten_multiplier)], true)
	else:
		_show_toast("%s wins by %.2fs" % [
			display_name, player_time - rival_time], false)


func _rival_name() -> String:
	if _rival_racer == null:
		_rival_racer = get_tree().get_first_node_in_group("rival_racer")
	if _rival_racer == null:
		return "the rival"
	var rival_name: String = _rival_racer.current_rival_name()
	return rival_name if rival_name != "" else "the rival"


func _on_offline_earnings_granted(amount: float, elapsed_seconds: float) -> void:
	_show_toast(
		"Away %s  +$%s" % [_format_duration(elapsed_seconds), format_money(amount)],
		true,
	)


func _show_toast(message: String, highlight: bool) -> void:
	_toast_label.text = message
	_toast_label.self_modulate = Color(1.0, 0.85, 0.3) if highlight else Color.WHITE
	if _toast_tween:
		_toast_tween.kill()
	_toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)


func _refresh_pips() -> void:
	var pips := ""
	for i in _pips_total:
		pips += PIP_FULL if i < _pips_filled else PIP_EMPTY
	_pips_label.text = pips


static func format_money(amount: float) -> String:
	if amount >= 1_000_000.0:
		return "%.2fM" % (amount / 1_000_000.0)
	if amount >= 10_000.0:
		return "%.1fk" % (amount / 1_000.0)
	return "%d" % int(amount)


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "-:--.--"
	return "%d:%05.2f" % [int(seconds / 60.0), fmod(seconds, 60.0)]


static func _format_duration(seconds: float) -> String:
	if seconds >= 3600.0:
		return "%dh %02dm" % [int(seconds / 3600.0), int(fmod(seconds, 3600.0) / 60.0)]
	if seconds >= 60.0:
		return "%dm %02ds" % [int(seconds / 60.0), int(fmod(seconds, 60.0))]
	return "%ds" % int(seconds)
