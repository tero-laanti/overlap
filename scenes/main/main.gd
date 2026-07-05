extends Node2D
## Composition root. Instantiates track, car, and UI, and wires their
## signals. Owns no gameplay logic — see CLAUDE.md hard rule 1.

const RaceStateScript = preload("res://scenes/main/race_state.gd")
const TrackScript = preload("res://scenes/track/track.gd")

@onready var _track: TrackScript = $Track
@onready var _race_state: RaceStateScript = $RaceState


func _ready() -> void:
	_race_state.car = $Car
	_track.lap_started.connect(_race_state.on_lap_started)
	_track.lap_completed.connect(_race_state.on_lap_completed)
	Bank.set_active_track_payout(_track.def.base_payout)
	if Bank.best_recording != null:
		_race_state.adopt_best(Bank.best_recording)
		Events.best_lap_recorded.emit(Bank.best_recording)
	var hud := $HUD
	hud.race_state = _race_state
	hud.car = $Car
	_track.lap_started.connect(hud.on_lap_started)
	_track.checkpoint_crossed.connect(hud.on_checkpoint_crossed)
