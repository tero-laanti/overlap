extends Node
## Economy and persistence. Pure data — never references scene nodes.
## Every authored route keeps its own PB recording; each route's ghost
## fleet pays that route's payout per completed ghost lap, so income per
## second is Σ over routes of ghost_slots × payout / pb. Gates and route
## discovery live here too: a lap on an undiscovered route discovers it.
## State is saved with store_var (plain data only, no serialized objects).

const SAVE_PATH := "user://save.dat"
const SAVE_INTERVAL := 5.0
const EconomyDefScript = preload("res://autoload/economy_def.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")
const UpgradeCatalogScript = preload("res://scenes/car/upgrade_catalog.gd")
const TrackNetworkDefScript = preload("res://scenes/track/track_network_def.gd")
const GateDefScript = preload("res://scenes/track/gate_def.gd")
const RouteDefScript = preload("res://scenes/track/route_def.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")
const BankSaveScript = preload("res://autoload/bank_save.gd")
const BankMedalsScript = preload("res://autoload/bank_medals.gd")
const BankIncomeScript = preload("res://autoload/bank_income.gd")
const CATALOG: UpgradeCatalogScript = preload("res://data/upgrades/catalog.tres")
const ECONOMY: EconomyDefScript = preload("res://data/economy.tres")

var currency := 0.0
## route_id -> LapRecording (the PB; pb time is recording.lap_time).
var route_records := {}
var discovered_routes: Array[String] = []
var purchased_gates: Array[String] = []
var unlocked_secrets: Array[String] = []
var rivals_beaten: Array[String] = []
## One-way latch: the GARAGE (and upgrades) open once driving earnings
## reach ECONOMY.garage_unlock_cash.
var garage_unlocked := false
var upgrade_levels := {}
## The gateway equipment: ramps launch properly only once owned.
var jump_kit_owned := false
## 0 until the LAST onboarding rival is beaten — that win hires ghost #1,
## and passive income starts there, never before. Active laps still pay.
var ghost_slots := 0

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


func route_ghost_color(route_id: String) -> Color:
	var route := _network.find_route(route_id) if _network else null
	return route.ghost_color if route else Color(0.35, 0.8, 1.0)


func route_pb(route_id: String) -> float:
	var recording: LapRecordingScript = route_records.get(route_id)
	return recording.lap_time if recording else 0.0


func authored_routes() -> Array[RouteDefScript]:
	if _network == null:
		var none: Array[RouteDefScript] = []
		return none
	return _network.routes


## Undriven but no longer unknown: every gate the route needs is owned.
## Secret routes are never hinted — they live only in the counter.
func is_route_hinted(route_id: String) -> bool:
	if route_id in discovered_routes or _network == null:
		return false
	var route := _network.find_route(route_id)
	if route == null or route.secret:
		return false
	for gate_id in route.required_gates:
		if not is_gate_purchased(gate_id):
			return false
	return true


func milestone_multiplier() -> float:
	return BankIncomeScript.milestone_multiplier(self)


## Medal for a route — "", "bronze", "silver" or "gold" — free
## recognition derived from PB vs par, never stored, no economy effect.
func route_medal(route_id: String) -> String:
	return BankMedalsScript.tier(self, route_id)


func is_rival_beaten(rival_id: String) -> bool:
	return rival_id in rivals_beaten


## A rival's arrival requirement: none (onboarding), the Jump Kit (the
## special id "jump_kit" — island residents), or a purchased gate.
func rival_requirement_met(rival: RivalDefScript) -> bool:
	if rival.required_gate == "":
		return true
	if rival.required_gate == "jump_kit":
		return jump_kit_owned
	return is_gate_purchased(rival.required_gate)


## A rival stands (parked on the grid, racing your laps) once its
## requirement is met and every earlier tier on its route has fallen.
func is_rival_active(rival_id: String) -> bool:
	if _network == null:
		return false
	var target := _network.find_rival(rival_id)
	if target == null or target.id in rivals_beaten:
		return false
	if not rival_requirement_met(target):
		return false
	for rival in _network.rivals:
		if rival == target:
			break
		if rival.route_id == target.route_id and rival.id not in rivals_beaten:
			return false
	return true


## A route's fleet only earns once no standing rival holds that route —
## the onboarding ladder gates the ring, residents gate their annex.
func is_route_fleet_active(route_id: String) -> bool:
	if _network == null:
		return true
	for rival in _network.rivals:
		if rival.route_id == route_id and rival.id not in rivals_beaten \
				and rival_requirement_met(rival):
			return false
	return true


## The standing rival a freshly bought gate introduces, if any.
func rival_for_gate(gate_id: String) -> RivalDefScript:
	if _network == null:
		return null
	for rival in _network.rivals:
		if rival.required_gate == gate_id and rival.id not in rivals_beaten:
			return rival
	return null


## Every beaten ONBOARDING rival doubles ACTIVE lap payouts — the ring
## ladder is the whole income curve until ghosts exist. Residents don't
## compound it; their prize is the fleet they release.
func rival_multiplier() -> float:
	if _network == null:
		return 1.0
	var beaten_onboarding := 0
	for rival in _network.rivals:
		if rival.required_gate == "" and rival.id in rivals_beaten:
			beaten_onboarding += 1
	return pow(ECONOMY.rival_beaten_multiplier, beaten_onboarding)


## Beating a rival releases whatever it held; the final onboarding win
## also hires your first ghost.
func mark_rival_beaten(rival_id: String, hires_ghost: bool) -> void:
	if rival_id in rivals_beaten:
		return
	rivals_beaten.append(rival_id)
	if hires_ghost and ghost_slots < 1:
		ghost_slots = 1
	save_profile()
	Events.rival_beaten.emit(rival_id)
	if hires_ghost:
		Events.ghost_hired.emit(ghost_slots)


func is_secret_unlocked(secret_id: String) -> bool:
	return secret_id in unlocked_secrets


func unlock_secret(secret_id: String) -> void:
	if secret_id in unlocked_secrets:
		return
	unlocked_secrets.append(secret_id)
	save_profile()
	Events.secret_unlocked.emit(secret_id)


func route_income_per_second(route_id: String) -> float:
	return BankIncomeScript.route_income_per_second(self, route_id)


func income_per_second() -> float:
	return BankIncomeScript.income_per_second(self)


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


func jump_kit_cost() -> float:
	return ECONOMY.jump_kit_cost


func try_buy_jump_kit() -> bool:
	if jump_kit_owned or currency < ECONOMY.jump_kit_cost:
		return false
	currency -= ECONOMY.jump_kit_cost
	jump_kit_owned = true
	save_profile()
	Events.currency_changed.emit(currency)
	Events.jump_kit_purchased.emit()
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
	# Belt over the fleet gate: a route held by a standing rival never
	# pays a ghost lap, even if a stray ghost exists.
	if not is_route_fleet_active(route_id):
		return
	currency += route_payout(route_id) * milestone_multiplier()
	_dirty = true
	Events.currency_changed.emit(currency)


## Active play always out-earns watching: your own laps pay a multiple of
## the ghost payout. First lap on a route also discovers it.
func _on_player_lap_completed(route_id: String, _lap_time: float, _is_best: bool) -> void:
	currency += route_payout(route_id) * ECONOMY.active_lap_multiplier \
			* rival_multiplier() * milestone_multiplier()
	_dirty = true
	Events.currency_changed.emit(currency)
	if not garage_unlocked and currency >= ECONOMY.garage_unlock_cash:
		garage_unlocked = true
		save_profile()
		Events.garage_unlocked.emit()
	if route_id not in discovered_routes:
		discovered_routes.append(route_id)
		save_profile()
		var route := _network.find_route(route_id) if _network else null
		Events.route_discovered.emit(route_id,
				route.display_name if route else route_id)


func _on_best_lap_recorded(route_id: String, recording: LapRecordingScript) -> void:
	# PB only ever improves, so the derived medal only ever upgrades —
	# a tier change on a new best is always a freshly earned medal.
	var tier_before := route_medal(route_id)
	route_records[route_id] = recording
	save_profile()
	var tier_after := route_medal(route_id)
	if tier_after != tier_before and tier_after != "":
		Events.medal_earned.emit(route_id, tier_after)


func save_profile() -> void:
	BankSaveScript.write(SAVE_PATH, self)
	_dirty = false
	_save_timer = 0.0


func load_profile() -> void:
	_loaded_save_unix = BankSaveScript.read_into(SAVE_PATH, self)
	Events.currency_changed.emit(currency)


## Dev tool: wipe every bit of progress and the save file. Callers are
## expected to reload the scene afterwards so nodes rebuild from zero.
func reset_profile() -> void:
	currency = 0.0
	route_records.clear()
	discovered_routes.clear()
	purchased_gates.clear()
	unlocked_secrets.clear()
	rivals_beaten.clear()
	garage_unlocked = false
	upgrade_levels.clear()
	jump_kit_owned = false
	ghost_slots = 0
	_loaded_save_unix = 0.0
	_dirty = false
	_save_timer = 0.0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	Events.currency_changed.emit(currency)
	Events.profile_reset.emit()


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
