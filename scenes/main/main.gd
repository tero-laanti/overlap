extends Node2D
## Composition root. Instantiates track, car, and UI, and wires their
## signals. Owns no gameplay logic — see AGENTS.md hard rule 1.

const RaceStateScript = preload("res://scenes/main/race_state.gd")
const TrackScript = preload("res://scenes/track/track.gd")
const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")

@onready var _track: TrackScript = $Track
@onready var _race_state: RaceStateScript = $RaceState


func _ready() -> void:
	_race_state.car = $Car
	_track.lap_started.connect(_race_state.on_lap_started)
	_track.lap_completed.connect(_race_state.on_lap_completed)
	_track.lap_started.connect($Rivals.on_lap_started)
	Bank.set_active_network(_track.network)
	for route_id: String in Bank.route_records:
		var recording: LapRecordingScript = Bank.route_records[route_id]
		_race_state.adopt_best(route_id, recording)
		Events.best_lap_recorded.emit(route_id, recording)
	var hud := $HUD
	hud.race_state = _race_state
	hud.car = $Car
	_track.lap_started.connect(hud.on_lap_started)
	_track.checkpoint_crossed.connect(hud.on_checkpoint_crossed)
