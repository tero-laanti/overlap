extends Node
## One-shot stingers for economy and progression facts off the Events
## bus, plus the music loop. Presentation only — connects to signals,
## reads nothing, owns no state. Ghost laps are deliberately silent:
## at fleet scale a per-lap tick would be cacophony.

const MUSIC_PATH := "res://assets/audio/music/chill_loop.ogg"


func _ready() -> void:
	# Headless never mixes audio; playing would leak playbacks at exit.
	if DisplayServer.get_name() == "headless":
		return
	Events.upgrade_purchased.connect(func(_id: String, _level: int) -> void:
		$Purchase.play())
	Events.ghost_hired.connect(func(_count: int) -> void: $Purchase.play())
	Events.medal_earned.connect(func(_route_id: String, _tier: String) -> void:
		$Medal.play())
	Events.rival_beaten.connect(func(_rival_id: String) -> void: $Medal.play())
	Events.gate_purchased.connect(func(_gate_id: String) -> void: $Gate.play())
	Events.jump_kit_purchased.connect(func() -> void: $Gate.play())
	Events.route_discovered.connect(func(_id: String, _name: String) -> void:
		$Discovery.play())
	Events.secret_unlocked.connect(func(_id: String) -> void: $Discovery.play())
	Events.offline_earnings_granted.connect(func(_amount: float, _s: float) -> void:
		$Purchase.play())
	Events.lap_completed.connect(func(_id: String, _time: float, is_best: bool) -> void:
		if is_best:
			$Pb.play()
		else:
			$Lap.play())
	# The music loop is optional until an asset lands (see task/SOURCES).
	if ResourceLoader.exists(MUSIC_PATH):
		var stream := load(MUSIC_PATH)
		stream.loop = true
		$Music.stream = stream
		$Music.play()
