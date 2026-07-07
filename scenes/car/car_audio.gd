extends Node
## Drives the car's sounds from its physics state — reads the parent
## Car, never writes it. The generated loop WAVs are exactly
## LOOP_SECONDS long with integer-Hz partials, so loop points are set
## here at runtime instead of via import metadata.

const CarScript = preload("res://scenes/car/car.gd")
## dB per second toward each loop's target volume — fast enough to feel
## instant, slow enough not to click.
const FADE_DB_PER_SECOND := 300.0
const SILENT_DB := -60.0
## Rumble only reads as movement above this speed.
const OFFROAD_MIN_SPEED := 120.0
const SAMPLED_ENGINE := "res://assets/audio/sfx/engine_sample.wav"

## A/B for the human ear pass: swap the synth engine for the CC0
## recorded sample (see assets/audio/SOURCES.md), pick the better one.
@export var use_sampled_engine := false
@export var engine_pitch_min := 0.7
@export var engine_pitch_max := 2.1
@export var engine_db_min := -22.0
@export var engine_db_max := -10.0
@export var drift_db := -11.0
@export var offroad_db := -13.0

@onready var _car: CarScript = get_parent()
@onready var _engine: AudioStreamPlayer = $Engine
@onready var _drift: AudioStreamPlayer = $Drift
@onready var _offroad: AudioStreamPlayer = $Offroad
@onready var _splash: AudioStreamPlayer = $Splash


func _ready() -> void:
	# Headless never mixes audio, so playing streams would just leak
	# playback objects at exit (probe/calibrate runs stay error-clean).
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	if use_sampled_engine and ResourceLoader.exists(SAMPLED_ENGINE):
		_engine.stream = load(SAMPLED_ENGINE)
	for player: AudioStreamPlayer in [_engine, _drift, _offroad]:
		_make_looping(player)
		player.volume_db = SILENT_DB
		player.play()
	Events.car_reset_to_road.connect(func() -> void: _splash.play())


## Loop the whole stream: the generated WAVs are authored seam-free
## end-to-end, so no import metadata is needed.
func _make_looping(player: AudioStreamPlayer) -> void:
	var stream: AudioStreamWAV = player.stream
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)


func _physics_process(delta: float) -> void:
	var speed := _car.velocity.length()
	var speed_fraction := clampf(speed / _car.effective_stats().max_speed, 0.0, 1.0)
	_engine.pitch_scale = lerpf(engine_pitch_min, engine_pitch_max, speed_fraction)
	_fade(_engine, lerpf(engine_db_min, engine_db_max, speed_fraction), delta)
	_fade(_drift, drift_db if _car.is_sliding() else SILENT_DB, delta)
	var rumbling := not _car.is_on_road_now() and speed > OFFROAD_MIN_SPEED
	_fade(_offroad, offroad_db if rumbling else SILENT_DB, delta)


func _fade(player: AudioStreamPlayer, target_db: float, delta: float) -> void:
	player.volume_db = move_toward(player.volume_db, target_db,
			FADE_DB_PER_SECOND * delta)
