extends Node
## Global signal bus. Cross-scene facts only — carries no state.
## Past tense = something happened. Scenes emit; interested scenes connect.

const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")

signal lap_completed(route_id: String, lap_time: float, is_best: bool)
signal best_lap_recorded(route_id: String, recording: LapRecordingScript)
signal currency_changed(amount: float)
signal offline_earnings_granted(amount: float, elapsed_seconds: float)
signal ghost_lap_completed(route_id: String)
signal ghost_hired(slot_count: int)
signal upgrade_purchased(id: String, level: int)
signal gate_purchased(gate_id: String)
signal route_discovered(route_id: String, display_name: String)
signal medal_unlocked(route_id: String)
