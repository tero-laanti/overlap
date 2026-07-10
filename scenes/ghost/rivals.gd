extends Node2D
## Host for every rival on the active track: spawns one RivalRacer per
## network RivalDef (authored order preserved — it is the ladder order)
## and forwards lap starts. No rules here; activity lives in Bank,
## racing in each racer.

const RACER_SCENE := preload("res://scenes/ghost/rival_racer.tscn")
const RivalRacerScript = preload("res://scenes/ghost/rival_racer.gd")
const TrackScript = preload("res://scenes/track/track.gd")


func _ready() -> void:
	var track: TrackScript = get_tree().get_first_node_in_group("track")
	if track == null or track.network == null:
		return
	for def in track.network.rivals:
		var racer: RivalRacerScript = RACER_SCENE.instantiate()
		racer.def = def
		add_child(racer)


func on_lap_started() -> void:
	for racer: RivalRacerScript in get_children():
		racer.on_lap_started()
