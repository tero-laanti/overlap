extends Node2D
## The onboarding rival ladder: one named, opaque car at a time parked
## on the grid, racing its authored recording head-to-head from every
## lap start. Finishing your lap under its time beats it and promotes
## the next tier; beating the last one hires your first ghost (Bank owns
## those facts). Owns the whole park/race/beaten flow per hard rule 2;
## the car itself is a dumb Ghost replay, no physics, no AI.

const GhostScript = preload("res://scenes/ghost/ghost.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

const TAG_OFFSET := Vector2(0.0, -116.0)

## Ordered tiers; the active rival is the first unbeaten one.
@export var ladder: Array[RivalDefScript] = []

var _current: RivalDefScript

@onready var _ghost: GhostScript = $RivalGhost
@onready var _tag: Label = $NameTag


func _ready() -> void:
	add_to_group("rival_racer")
	Events.lap_completed.connect(_on_lap_completed)
	Events.car_reset_to_road.connect(_park)
	# Dev wipes re-arm the ladder without a scene reload (probe runs
	# reset in a sibling _ready, in either tree order).
	Events.profile_reset.connect(_sync_active)
	_sync_active()


func _process(_delta: float) -> void:
	_tag.position = _ghost.position + TAG_OFFSET - Vector2(_tag.size.x / 2.0, 0.0)


func current_rival_name() -> String:
	return _current.display_name if _current else ""


## Wired by Main to the track's lap_started: the race restarts with you.
func on_lap_started() -> void:
	if _current == null:
		return
	_ghost.set_recording(_current.recording)
	_ghost.playing = true


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if _current == null or route_id != _current.route_id:
		return
	var won := lap_time < _current.recording.lap_time
	Events.rival_race_finished.emit(_current.id, _current.display_name,
			lap_time, _current.recording.lap_time, won)
	if won:
		Bank.mark_rival_beaten(_current.id, _current == ladder.back())
		_sync_active()
	else:
		_park()


func _park() -> void:
	if _current == null:
		return
	_ghost.set_recording(_current.recording)
	_ghost.playing = false


## The first unbeaten tier parks on the grid; after the last, hide.
func _sync_active() -> void:
	_current = null
	for def in ladder:
		if def != null and not Bank.is_rival_beaten(def.id):
			_current = def
			break
	visible = _current != null
	set_process(_current != null)
	if _current == null:
		return
	_tag.text = _current.display_name
	_tag.add_theme_color_override("font_color",
			_current.body_color.lightened(0.25))
	$RivalGhost/Body.color = _current.body_color
	$RivalGhost/Stripe.color = _current.stripe_color
	$RivalGhost/Spoiler.color = _current.body_color.darkened(0.4)
	_park()
