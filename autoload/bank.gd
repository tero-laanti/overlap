extends Node
## Economy and persistence. Pure data — never references scene nodes.
## Every authored route keeps its own PB recording; each route's ghost
## fleet pays that route's payout per completed ghost lap, so income per
## second is Σ over routes of ghost_slots × payout / pb. Gates and route
## discovery live here too: a lap on an undiscovered route discovers it.
## State is saved with store_var (plain data only, no serialized objects).

const SAVE_PATH := "user://save.dat"
const SAVE_INTERVAL := 5.0
const SAVE_VERSION := 3
const EconomyDefScript = preload("res://autoload/economy_def.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const UpgradeCatalogScript = preload("res://scenes/car/upgrade_catalog.gd")
const TrackNetworkDefScript = preload("res://scenes/track/track_network_def.gd")
const GateDefScript = preload("res://scenes/track/gate_def.gd")
const RouteDefScript = preload("res://scenes/track/route_def.gd")
const CATALOG: UpgradeCatalogScript = preload("res://data/upgrades/catalog.tres")
const ECONOMY: EconomyDefScript = preload("res://data/economy.tres")
## The route id every pre-network save's single best lap belongs to.
const LEGACY_ROUTE_ID := "ring"

var currency := 0.0
## route_id -> LapRecording (the PB; pb time is recording.lap_time).
var route_records := {}
var discovered_routes: Array[String] = []
var purchased_gates: Array[String] = []
var upgrade_levels := {}
var ghost_slots := 1

var _network: TrackNetworkDefScript
var _save_timer := 0.0
var _dirty := false
var _loaded_save_unix := 0.0
var _offline_granted := false


func _ready() -> void:
	Events.best_lap_recorded.connect(_on_best_lap_recorded)
	Events.ghost_lap_completed.connect(_on_ghost_lap_completed)
	Events.lap_completed.connect(_on_player_lap_completed)
	load_profile()


func _process(delta: float) -> void:
	_save_timer += delta
	if _dirty and _save_timer >= SAVE_INTERVAL:
		save_profile()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_profile()


func set_active_network(network: TrackNetworkDefScript) -> void:
	_network = network
	_apply_pending_offline_earnings()


func route_payout(route_id: String) -> float:
	if _network == null:
		return 0.0
	var route := _network.find_route(route_id)
	return route.payout_per_lap if route else 0.0


func route_pb(route_id: String) -> float:
	var recording: LapRecordingScript = route_records.get(route_id)
	return recording.lap_time if recording else 0.0


func authored_routes() -> Array[RouteDefScript]:
	if _network == null:
		var none: Array[RouteDefScript] = []
		return none
	return _network.routes


## Undriven but no longer unknown: every gate the route needs is owned.
func is_route_hinted(route_id: String) -> bool:
	if route_id in discovered_routes or _network == null:
		return false
	var route := _network.find_route(route_id)
	if route == null:
		return false
	for gate_id in route.required_gates:
		if not is_gate_purchased(gate_id):
			return false
	return true


## ×2 for every fleet milestone reached (10/25/50 ghosts by default).
func milestone_multiplier() -> float:
	var m := 1.0
	for count in ECONOMY.milestone_counts:
		if ghost_slots >= count:
			m *= ECONOMY.milestone_multiplier
	return m


func route_income_per_second(route_id: String) -> float:
	var pb := route_pb(route_id)
	if pb <= 0.0:
		return 0.0
	return ghost_slots * route_payout(route_id) * milestone_multiplier() / pb


func income_per_second() -> float:
	var total := 0.0
	for route_id: String in route_records:
		total += route_income_per_second(route_id)
	return total


func upgrade_level(id: String) -> int:
	return upgrade_levels.get(id, 0)


func upgrade_cost(id: String) -> float:
	var def := CATALOG.find(id)
	return def.cost_at(upgrade_level(id)) if def else INF


func try_buy_upgrade(id: String) -> bool:
	var def := CATALOG.find(id)
	if def == null:
		return false
	var level := upgrade_level(id)
	if level >= def.max_level:
		return false
	var cost := def.cost_at(level)
	if currency < cost:
		return false
	currency -= cost
	upgrade_levels[id] = level + 1
	save_profile()
	Events.currency_changed.emit(currency)
	Events.upgrade_purchased.emit(id, level + 1)
	return true


func ghost_slot_cost() -> float:
	return ECONOMY.ghost_base_cost * pow(ECONOMY.ghost_cost_growth, ghost_slots - 1)


func try_buy_ghost_slot() -> bool:
	var cost := ghost_slot_cost()
	if currency < cost:
		return false
	currency -= cost
	ghost_slots += 1
	save_profile()
	Events.currency_changed.emit(currency)
	Events.ghost_hired.emit(ghost_slots)
	return true


func is_gate_purchased(gate_id: String) -> bool:
	return gate_id in purchased_gates


func gate_cost(gate_id: String) -> float:
	if _network == null:
		return INF
	var gate := _network.find_gate(gate_id)
	return gate.price if gate else INF


func unpurchased_gates() -> Array[GateDefScript]:
	var open: Array[GateDefScript] = []
	if _network == null:
		return open
	for gate in _network.gates:
		if not is_gate_purchased(gate.id):
			open.append(gate)
	return open


func try_buy_gate(gate_id: String) -> bool:
	if is_gate_purchased(gate_id):
		return false
	var cost := gate_cost(gate_id)
	if currency < cost:
		return false
	currency -= cost
	purchased_gates.append(gate_id)
	save_profile()
	Events.currency_changed.emit(currency)
	Events.gate_purchased.emit(gate_id)
	return true


func _on_ghost_lap_completed(route_id: String) -> void:
	currency += route_payout(route_id) * milestone_multiplier()
	_dirty = true
	Events.currency_changed.emit(currency)


## Active play always out-earns watching: your own laps pay a multiple of
## the ghost payout. First lap on a route also discovers it.
func _on_player_lap_completed(route_id: String, _lap_time: float, _is_best: bool) -> void:
	currency += route_payout(route_id) * ECONOMY.active_lap_multiplier \
			* milestone_multiplier()
	_dirty = true
	Events.currency_changed.emit(currency)
	if route_id not in discovered_routes:
		discovered_routes.append(route_id)
		save_profile()
		var route := _network.find_route(route_id) if _network else null
		Events.route_discovered.emit(route_id,
				route.display_name if route else route_id)


func _on_best_lap_recorded(route_id: String, recording: LapRecordingScript) -> void:
	route_records[route_id] = recording
	save_profile()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Bank: cannot write save file: %s" % FileAccess.get_open_error())
		return
	var routes := {}
	for route_id: String in route_records:
		var recording: LapRecordingScript = route_records[route_id]
		routes[route_id] = {
			"sample_dt": recording.sample_dt,
			"positions": recording.positions,
			"rotations": recording.rotations,
			"lap_time": recording.lap_time,
		}
	file.store_var({
		"version": SAVE_VERSION,
		"currency": currency,
		"upgrade_levels": upgrade_levels,
		"ghost_slots": ghost_slots,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"routes": routes,
		"discovered_routes": discovered_routes,
		"purchased_gates": purchased_gates,
	})
	_dirty = false
	_save_timer = 0.0


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return
	currency = data.get("currency", 0.0)
	upgrade_levels = data.get("upgrade_levels", {})
	ghost_slots = data.get("ghost_slots", 1)
	_loaded_save_unix = data.get("saved_at_unix", 0.0)
	if int(data.get("version", 1)) < 3:
		_migrate_v2(data)
	else:
		for route_id: String in data.get("routes", {}):
			route_records[route_id] = _recording_from(data["routes"][route_id])
		discovered_routes.assign(data.get("discovered_routes", []))
		purchased_gates.assign(data.get("purchased_gates", []))
	Events.currency_changed.emit(currency)


## v2 saves had a single best lap: it becomes the legacy route's record.
func _migrate_v2(data: Dictionary) -> void:
	var lap: Variant = data.get("best_lap")
	if lap is Dictionary:
		route_records[LEGACY_ROUTE_ID] = _recording_from(lap)
		discovered_routes.append(LEGACY_ROUTE_ID)


func _recording_from(lap: Dictionary) -> LapRecordingScript:
	var recording := LapRecordingScript.new()
	recording.sample_dt = lap.get("sample_dt", 1.0 / 30.0)
	recording.positions = lap.get("positions", PackedVector2Array())
	recording.rotations = lap.get("rotations", PackedFloat32Array())
	recording.lap_time = lap.get("lap_time", 0.0)
	return recording


func _apply_pending_offline_earnings() -> void:
	if _offline_granted or _loaded_save_unix <= 0.0:
		return
	_offline_granted = true
	var elapsed := maxf(0.0, Time.get_unix_time_from_system() - _loaded_save_unix)
	var capped_elapsed := minf(elapsed, ECONOMY.offline_cap_seconds)
	var earned := income_per_second() * capped_elapsed
	if earned <= 0.0:
		return
	currency += earned
	_dirty = true
	Events.currency_changed.emit(currency)
	Events.offline_earnings_granted.emit(earned, capped_elapsed)
	save_profile()
