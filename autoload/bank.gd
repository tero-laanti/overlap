extends Node
## Economy and persistence. Pure data — never references scene nodes.
## Each completed ghost lap pays the active track's base payout, so income
## per second is ghost_slots × payout / lap_time and improves with every
## PB, every upgrade-driven faster lap, and every hired ghost. State is
## saved with store_var (plain data only, no serialized objects).

const SAVE_PATH := "user://save.dat"
const SAVE_INTERVAL := 5.0
const CATALOG: UpgradeCatalog = preload("res://data/upgrades/catalog.tres")
const ECONOMY: EconomyDef = preload("res://data/economy.tres")

var currency := 0.0
var best_recording: LapRecording
var active_track_payout := 0.0
var upgrade_levels := {}
var ghost_slots := 1

var _save_timer := 0.0
var _dirty := false


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


## ×2 for every fleet milestone reached (10/25/50 ghosts by default).
func milestone_multiplier() -> float:
	var m := 1.0
	for count in ECONOMY.milestone_counts:
		if ghost_slots >= count:
			m *= ECONOMY.milestone_multiplier
	return m


func income_per_second() -> float:
	if best_recording == null or best_recording.lap_time <= 0.0:
		return 0.0
	return ghost_slots * active_track_payout * milestone_multiplier() \
			/ best_recording.lap_time


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


func _on_ghost_lap_completed() -> void:
	currency += active_track_payout * milestone_multiplier()
	_dirty = true
	Events.currency_changed.emit(currency)


## Active play always out-earns watching: your own laps pay a multiple of
## the ghost payout.
func _on_player_lap_completed(_lap_time: float, _is_best: bool) -> void:
	currency += active_track_payout * ECONOMY.active_lap_multiplier \
			* milestone_multiplier()
	_dirty = true
	Events.currency_changed.emit(currency)


func _on_best_lap_recorded(recording: LapRecording) -> void:
	best_recording = recording
	save_profile()


func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Bank: cannot write save file: %s" % FileAccess.get_open_error())
		return
	var data := {
		"version": 1,
		"currency": currency,
		"upgrade_levels": upgrade_levels,
		"ghost_slots": ghost_slots,
	}
	if best_recording != null:
		data["best_lap"] = {
			"sample_dt": best_recording.sample_dt,
			"positions": best_recording.positions,
			"rotations": best_recording.rotations,
			"lap_time": best_recording.lap_time,
		}
	file.store_var(data)
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
	var lap: Variant = data.get("best_lap")
	if lap is Dictionary:
		best_recording = LapRecording.new()
		best_recording.sample_dt = lap.get("sample_dt", 1.0 / 30.0)
		best_recording.positions = lap.get("positions", PackedVector2Array())
		best_recording.rotations = lap.get("rotations", PackedFloat32Array())
		best_recording.lap_time = lap.get("lap_time", 0.0)
	Events.currency_changed.emit(currency)
