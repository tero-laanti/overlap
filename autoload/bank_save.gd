class_name BankSave
extends RefCounted
## Save-file IO for Bank, split out to keep the autoload lean. Static
## functions operate on the Bank autoload passed in — no state here.
## Saves are plain data via store_var (no serialized objects).

## v4 = island v2 (docs/MAP_DESIGN_V2.md); v5 adds resident rivals.
## Pre-v4 saves are wiped, not migrated: their PB recordings replay
## geometry that no longer exists (human-approved full reset,
## 2026-07-07). v4 loads with the resident grandfather below.
const SAVE_VERSION := 5
const OLDEST_LOADABLE_VERSION := 4
## Keep both in sync with the rivals authored in track02_network.tres.
const ONBOARDING_RIVALS: Array[String] = ["amber", "cobalt", "onyx"]
const RESIDENT_RIVALS := {"jade": "cut", "sienna": "dune",
		"slate": "climb", "rust": "harbor"}
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
		"rivals_beaten": bank.rivals_beaten,
		"garage_unlocked": bank.garage_unlocked,
		"jump_kit_owned": bank.jump_kit_owned,
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
	if int(data.get("version", 1)) < OLDEST_LOADABLE_VERSION:
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
	bank.rivals_beaten.assign(data.get("rivals_beaten", []))
	bank.garage_unlocked = data.get("garage_unlocked", false)
	bank.jump_kit_owned = data.get("jump_kit_owned", false)
	# Owning any ghost slot implies the whole onboarding is behind this
	# profile — beating the final rival is the only path from 0 to 1 —
	# so saves from before the current ladder are grandfathered by
	# invariant, never re-gated. (Keep in sync with the ladder ids
	# authored in main.tscn / data/rivals/.)
	if bank.ghost_slots >= 1:
		for rival_id in ONBOARDING_RIVALS:
			if rival_id not in bank.rivals_beaten:
				bank.rivals_beaten.append(rival_id)
		bank.garage_unlocked = true
	# v4 predates residents: a route already earning keeps earning — its
	# resident counts as beaten. v5+ saves know their own rival state.
	if int(data.get("version", 1)) == 4:
		for rival_id: String in RESIDENT_RIVALS:
			if bank.route_records.has(RESIDENT_RIVALS[rival_id]) \
					and rival_id not in bank.rivals_beaten:
				bank.rivals_beaten.append(rival_id)
	return data.get("saved_at_unix", 0.0)


static func _recording_from(lap: Dictionary) -> LapRecordingScript:
	var recording := LapRecordingScript.new()
	recording.sample_dt = lap.get("sample_dt", 1.0 / 30.0)
	recording.positions = lap.get("positions", PackedVector2Array())
	recording.rotations = lap.get("rotations", PackedFloat32Array())
	recording.lap_time = lap.get("lap_time", 0.0)
	return recording
