extends Node2D
## One named, opaque rival car: parks on the grid while its RivalDef is
## active (Bank owns that rule), races its authored recording head-to-
## head from every lap start, and reports the result. Beating it on its
## route releases whatever it held. Owns the park/race/beaten flow per
## hard rule 2; the car itself is a dumb Ghost replay, no physics, no
## AI. Spawned by the Rivals host, one per network rival.

const GhostScript = preload("res://scenes/ghost/ghost.gd")
const RivalDefScript = preload("res://scenes/ghost/rival_def.gd")

const TAG_OFFSET := Vector2(0.0, -116.0)

var def: RivalDefScript

@onready var _ghost: GhostScript = $RivalGhost
@onready var _tag: Label = $NameTag


func _ready() -> void:
	add_to_group("rival_racer")
	Events.lap_completed.connect(_on_lap_completed)
	Events.car_reset_to_road.connect(_park)
	Events.rival_beaten.connect(func(_id: String) -> void: _sync_active())
	Events.gate_purchased.connect(func(_id: String) -> void: _sync_active())
	Events.profile_reset.connect(_sync_active)
	if def != null:
		_tag.text = def.display_name
		_tag.add_theme_color_override("font_color", def.body_color.lightened(0.25))
		$RivalGhost/Body.color = def.body_color
		$RivalGhost/Stripe.color = def.stripe_color
		$RivalGhost/Spoiler.color = def.body_color.darkened(0.4)
	# Deferred: is_rival_active needs the network, which Bank learns in
	# Main._ready — after this node's _ready.
	_sync_active.call_deferred()


func _process(_delta: float) -> void:
	_tag.position = _ghost.position + TAG_OFFSET - Vector2(_tag.size.x / 2.0, 0.0)


func current_rival_name() -> String:
	return def.display_name if visible and def != null else ""


## Forwarded by the Rivals host from the track's lap_started: every
## standing rival's race restarts with you.
func on_lap_started() -> void:
	if not visible:
		return
	_ghost.set_recording(def.recording)
	_ghost.playing = true


func _on_lap_completed(route_id: String, lap_time: float, _is_best: bool) -> void:
	if not visible or def == null or route_id != def.route_id:
		return
	var won := lap_time < def.recording.lap_time
	Events.rival_race_finished.emit(def.id, def.display_name,
			lap_time, def.recording.lap_time, won)
	if won:
		Bank.mark_rival_beaten(def.id, def.hires_first_ghost)
	else:
		_park()


func _park() -> void:
	if def == null:
		return
	_ghost.set_recording(def.recording)
	_ghost.playing = false


func _sync_active() -> void:
	var active := def != null and Bank.is_rival_active(def.id)
	visible = active
	set_process(active)
	if active:
		_park()
