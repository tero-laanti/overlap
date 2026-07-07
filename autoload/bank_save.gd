class_name BankSave
extends RefCounted
## Save-file IO for Bank, split out to keep the autoload lean. Static
## functions operate on the Bank autoload passed in — no state here.
## Saves are plain data via store_var (no serialized objects).

## v4 = island v2 (docs/MAP_DESIGN_V2.md). Older saves are wiped, not
## migrated: their PB recordings replay geometry that no longer exists
## (human-approved full reset, 2026-07-07).
const SAVE_VERSION := 4
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")


## Atomic: written to a temp file first, then renamed over the real one,
## so a crash mid-write never leaves a truncated save behind.
static func write(path: String, bank: Node) -> void:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("BankSave: cannot write save file: %s" % FileAccess.get_open_error())
		return
	var routes := {}
	for route_id: String in bank.route_records:
		var recording: LapRecordingScript = bank.route_records[route_id]
		routes[route_id] = {
			"sample_dt": recording.sample_dt,
			"positions": recording.positions,
			"rotations": recording.rotations,
			"lap_time": recording.lap_time,
		}
	file.store_var({
		"version": SAVE_VERSION,
		"currency": bank.currency,
		"upgrade_levels": bank.upgrade_levels,
		"ghost_slots": bank.ghost_slots,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"routes": routes,
		"discovered_routes": bank.discovered_routes,
		"purchased_gates": bank.purchased_gates,
		"medal_unlocked_routes": bank.medal_unlocked_routes,
		"unlocked_secrets": bank.unlocked_secrets,
	})
	file.close()
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("BankSave: cannot replace save file: %s" % error_string(err))


## Returns the loaded save's unix timestamp, or 0.0 when nothing loaded.
static func read_into(path: String, bank: Node) -> float:
	if not FileAccess.file_exists(path):
		return 0.0
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0.0
	var data: Variant = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return 0.0
	if int(data.get("version", 1)) < SAVE_VERSION:
		return 0.0
	bank.currency = data.get("currency", 0.0)
	bank.upgrade_levels = data.get("upgrade_levels", {})
	bank.ghost_slots = data.get("ghost_slots", 1)
	for route_id: String in data.get("routes", {}):
		bank.route_records[route_id] = _recording_from(data["routes"][route_id])
	bank.discovered_routes.assign(data.get("discovered_routes", []))
	bank.purchased_gates.assign(data.get("purchased_gates", []))
	bank.medal_unlocked_routes.assign(data.get("medal_unlocked_routes", []))
	bank.unlocked_secrets.assign(data.get("unlocked_secrets", []))
	return data.get("saved_at_unix", 0.0)


static func _recording_from(lap: Dictionary) -> LapRecordingScript:
	var recording := LapRecordingScript.new()
	recording.sample_dt = lap.get("sample_dt", 1.0 / 30.0)
	recording.positions = lap.get("positions", PackedVector2Array())
	recording.rotations = lap.get("rotations", PackedFloat32Array())
	recording.lap_time = lap.get("lap_time", 0.0)
	return recording
