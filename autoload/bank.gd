extends Node
## Economy and persistence. Pure data — never references scene nodes.
## Each completed ghost lap pays the active track's base payout, so income
## per second is payout / lap_time and improves with every PB. State is
## saved with store_var (plain data only, no serialized objects).

const SAVE_PATH := "user://save.dat"
const SAVE_INTERVAL := 5.0

var currency := 0.0
var best_recording: LapRecording
var active_track_payout := 0.0

var _save_timer := 0.0
var _dirty := false


func _ready() -> void:
	Events.best_lap_recorded.connect(_on_best_lap_recorded)
	Events.ghost_lap_completed.connect(_on_ghost_lap_completed)
	load_profile()


func _process(delta: float) -> void:
	_save_timer += delta
	if _dirty and _save_timer >= SAVE_INTERVAL:
		save_profile()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_profile()


func income_per_second() -> float:
	if best_recording == null or best_recording.lap_time <= 0.0:
		return 0.0
	return active_track_payout / best_recording.lap_time


func _on_ghost_lap_completed() -> void:
	currency += active_track_payout
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
	var data := {"version": 1, "currency": currency}
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
	var lap: Variant = data.get("best_lap")
	if lap is Dictionary:
		best_recording = LapRecording.new()
		best_recording.sample_dt = lap.get("sample_dt", 1.0 / 30.0)
		best_recording.positions = lap.get("positions", PackedVector2Array())
		best_recording.rotations = lap.get("rotations", PackedFloat32Array())
		best_recording.lap_time = lap.get("lap_time", 0.0)
	Events.currency_changed.emit(currency)
