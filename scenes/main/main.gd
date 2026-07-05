extends Node2D
## Composition root. Instantiates track, car, and UI, and wires their
## signals. Owns no gameplay logic — see CLAUDE.md hard rule 1.

@onready var _track: Track = $Track
@onready var _race_state: RaceState = $RaceState


func _ready() -> void:
	_track.lap_started.connect(_race_state.on_lap_started)
	_track.lap_completed.connect(_race_state.on_lap_completed)
	$HUD.race_state = _race_state
