extends Node2D
## The onboarding rival: a named, opaque car parked on the grid that
## races its authored recording head-to-head from every lap start.
## Finishing your lap under its time beats it — Bank then hires your
## first ghost. Owns the whole rival flow (park/race/beaten) per hard
## rule 2; the car itself is a dumb Ghost replay, no physics, no AI.

const GhostScript = preload("res://scenes/ghost/ghost.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

const TAG_OFFSET := Vector2(0.0, -116.0)

@export var def: RivalDefScript

@onready var _ghost: GhostScript = $RivalGhost
@onready var _tag: Label = $NameTag


func _ready() -> void:
	Events.lap_completed.connect(_on_lap_completed)
	Events.car_reset_to_road.connect(_park)
	# Dev wipes re-arm a beaten rival without a scene reload (probe runs
	# reset in a sibling _ready, in either tree order).
	Events.profile_reset.connect(_sync_active)
	_tag.text = def.display_name if def else ""
	_sync_active()


func _process(_delta: float) -> void:
	_tag.position = _ghost.position + TAG_OFFSET - Vector2(_tag.size.x / 2.0, 0.0)


## Wired by Main to the track's lap_started: the race restarts with you.
func on_lap_started() -> void:
	if not visible:
		return
	_ghost.set_recording(def.recording)
	_ghost.playing = true


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if not visible or def == null:
		return
	if route_id == def.route_id and lap_time < def.recording.lap_time:
		Bank.mark_rival_beaten(def.id)
		_sync_active()
	else:
		_park()


func _park() -> void:
	if def == null:
		return
	_ghost.set_recording(def.recording)
	_ghost.playing = false


## Parked on the grid until beaten; hidden and inert after.
func _sync_active() -> void:
	var active := def != null and not Bank.is_rival_beaten(def.id)
	visible = active
	set_process(active)
	if active:
		_park()
