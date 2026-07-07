extends Node
## Dev-only par calibrator. Dormant unless user://calibrate.flag exists
## (don't combine with autopilot.flag). Wipes the profile, grants money,
## opens every gate, maxes every upgrade, then drives each authored
## route with the shared autopilot and reports best laps — the numbers
## RouteDef.par_time is authored from. Rerun after any handling or
## catalog change and re-author pars. Buys each mastery unlock too, so
## the report shows the medal the maxed autopilot earns against current
## pars (expect gold once pars match this run's output).

const FLAG_PATH := "user://calibrate.flag"
const LAPS_PER_ROUTE := 3
const TIMEOUT := 600.0
const GRANT := 100000.0

const CarScript = preload("res://scenes/car/car.gd")
const DevDriverScript = preload("res://scenes/dev/dev_driver.gd")
const RoutesScript = preload("res://scenes/dev/dev_probe_routes.gd")

const TWIN_WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1260, 300), Vector2(-1520, 0),
	Vector2(-1260, -300), Vector2(-1050, -550),
	Vector2(300, -550), Vector2(300, -100), Vector2(300, 550),
]
## Through the golden tree gap — the first crossing also proves the
## secret unlock trigger fires from real driving.
const FOREST_WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550), Vector2(-660, -430),
	Vector2(-660, -1000), Vector2(-1500, -1400), Vector2(-900, -2100),
	Vector2(300, -1900), Vector2(900, -1200), Vector2(700, -550),
	Vector2(1050, -550), Vector2(1050, 550),
]
## The tree gap is 240 px wide — the default reach radius corner-cuts
## straight past it.
const FOREST_REACH := 120.0
## Same climb as the probe, but turning east at the X onto the top road
## instead of diving into the chord — the High Ring discovery.
const HIGH_RING_WAYPOINTS: Array[Vector2] = [
	Vector2(-1050, 550), Vector2(-1050, -550),
	Vector2(600, -550), Vector2(1100, -570),
	Vector2(1400, -790), Vector2(1540, -1120),
	Vector2(2250, -1120), Vector2(2400, -1180), Vector2(2420, -1290),
	Vector2(2400, -1400), Vector2(2250, -1460),
	Vector2(1650, -1460), Vector2(1500, -1520), Vector2(1480, -1630),
	Vector2(1500, -1740), Vector2(1650, -1800),
	Vector2(2250, -1800), Vector2(2440, -1880), Vector2(2470, -2010),
	Vector2(2440, -2140), Vector2(2250, -2220),
	Vector2(1720, -2280), Vector2(1280, -2160), Vector2(860, -2300),
	Vector2(520, -2150),
	Vector2(260, -1750), Vector2(230, -1350), Vector2(260, -950),
	Vector2(300, -750), Vector2(600, -560), Vector2(1050, -550),
	Vector2(1050, 0), Vector2(1050, 550),
]

var _driver: DevDriverScript = DevDriverScript.new()
var _route_ids: Array[String] = [
	"ring", "cut", "petal", "twin", "forest", "climb", "high_ring",
]
var _route_points := {
	"ring": RoutesScript.RING,
	"cut": RoutesScript.CUT,
	"petal": RoutesScript.PETAL,
	"twin": TWIN_WAYPOINTS,
	"forest": FOREST_WAYPOINTS,
	"climb": RoutesScript.CLIMB,
	"high_ring": HIGH_RING_WAYPOINTS,
}
## Routes whose mouths or hairpins need a tighter capture radius.
var _route_reach := {
	"forest": FOREST_REACH,
	"climb": RoutesScript.CLIFF_REACH,
	"high_ring": RoutesScript.CLIFF_REACH,
}
var _stage := -1
var _stage_laps := 0
var _elapsed := 0.0
var _next_telemetry := 0.0
var _prepped := false


func _ready() -> void:
	if not (OS.is_debug_build() and FileAccess.file_exists(FLAG_PATH)):
		set_process(false)
		return
	Bank.reset_profile()
	Bank.currency = GRANT
	_driver.car = get_tree().get_first_node_in_group("player_car")
	Events.lap_completed.connect(_on_lap_completed)
	# Gate prices need the active network, which Bank learns in
	# Main._ready — prep after that.
	_prep.call_deferred()


func _prep() -> void:
	for gate in Bank.unpurchased_gates():
		Bank.try_buy_gate(gate.id)
	for def in Bank.CATALOG.upgrades:
		while Bank.try_buy_upgrade(def.id):
			pass
	var car: CarScript = _driver.car
	print("[CAL] prepped money=%.0f max_speed=%.0f accel=%.0f grip=%.2f" % [
		Bank.currency, car.effective_stats().max_speed,
		car.effective_stats().acceleration, car.effective_stats().grip,
	])
	_prepped = true
	_next_stage()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= TIMEOUT:
		print("[CAL] TIMEOUT at stage %d" % _stage)
		_report()
		return
	if _prepped and _stage < _route_ids.size():
		_driver.drive(delta)
	if _elapsed >= _next_telemetry:
		_next_telemetry += 2.0
		var car: CarScript = _driver.car
		if car != null:
			print("[CAL] t=%.1f stage=%d pos=(%.0f, %.0f) speed=%.0f" % [
				_elapsed, _stage, car.global_position.x, car.global_position.y,
				car.velocity.length()])


func _next_stage() -> void:
	_stage += 1
	_stage_laps = 0
	if _stage >= _route_ids.size():
		_report()
		return
	var route_id := _route_ids[_stage]
	_driver.set_route(_route_points[route_id],
			_route_reach.get(route_id, DevDriverScript.WAYPOINT_REACHED_DISTANCE))
	print("[CAL] driving %s" % route_id)


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if _stage < 0 or _stage >= _route_ids.size():
		return
	if route_id != _route_ids[_stage]:
		return
	_stage_laps += 1
	print("[CAL] %s lap %d: %.2f" % [route_id, _stage_laps, lap_time])
	if _stage_laps >= LAPS_PER_ROUTE:
		Bank.try_buy_medal_unlock(route_id)
		_next_stage()


func _report() -> void:
	_driver.release_all()
	for route_id in _route_ids:
		print("[CAL] route=%s best=%.2f medal=%s" % [
			route_id, Bank.route_pb(route_id), Bank.route_medal(route_id)])
	print("[CAL] done — author par_time from the best laps above")
	set_process(false)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
