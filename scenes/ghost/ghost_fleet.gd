extends Node2D
## Owns the ghost instances on the track. Every ghost replays the single
## best lap — beating your PB upgrades the whole fleet at once. Slice 3:
## one ghost; purchasable slots and stagger offsets arrive with Bank.

const GHOST_SCENE := preload("res://scenes/ghost/ghost.tscn")


func _ready() -> void:
	Events.best_lap_recorded.connect(_on_best_lap_recorded)


func _on_best_lap_recorded(recording: LapRecording) -> void:
	if get_child_count() == 0:
		add_child(GHOST_SCENE.instantiate())
	for ghost: Ghost in get_children():
		ghost.set_recording(recording)
