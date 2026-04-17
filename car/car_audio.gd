class_name CarAudio
extends Node

## Plays sound for the three events the car emits: wall contacts (crashes),
## drift entry/exit, and throttle (the engine loop). Each slot accepts a
## supplied AudioStream; when left empty, a placeholder WAV is synthesized at
## ready-time so the prototype always has audible feedback.

const CarAudioPlaceholderRef := preload("res://car/car_audio_placeholder.gd")
const CRASH_MIN_SPEED := 6.0
const CRASH_RETRIGGER_SECONDS := 0.15
const ENGINE_IDLE_VOLUME_DB := -20.0
const ENGINE_FULL_VOLUME_DB := -6.0
const ENGINE_IDLE_PITCH := 0.7
const ENGINE_MAX_PITCH := 1.5
const DRIFT_VOLUME_DB := -10.0
const CRASH_VOLUME_DB := -4.0
const CRASH_PLAYER_NAME := "CrashPlayer"
const DRIFT_PLAYER_NAME := "DriftPlayer"
const ENGINE_PLAYER_NAME := "EnginePlayer"

@export var crash_stream: AudioStream
@export var drift_stream: AudioStream
@export var engine_stream: AudioStream

var car: Car = null

var _crash_player: AudioStreamPlayer = null
var _drift_player: AudioStreamPlayer = null
var _engine_player: AudioStreamPlayer = null
var _time_since_last_crash: float = CRASH_RETRIGGER_SECONDS
var _placeholder_audio: CarAudioPlaceholder = CarAudioPlaceholderRef.new()


func _ready() -> void:
	if car != null:
		bind_car(car)


func _process(delta: float) -> void:
	_time_since_last_crash += delta
	_update_engine_state()


func _exit_tree() -> void:
	_disconnect_car_signals()
	_release_player(_crash_player)
	_release_player(_drift_player)
	_release_player(_engine_player)
	_crash_player = null
	_drift_player = null
	_engine_player = null


func bind_car(car_owner: Car) -> void:
	if car != null and car != car_owner:
		_disconnect_car_signals()

	car = car_owner
	if car == null or not is_node_ready():
		return

	_ensure_players()

	if not car.drift_started.is_connected(_on_car_drift_started):
		car.drift_started.connect(_on_car_drift_started)
	if not car.drift_ended.is_connected(_on_car_drift_ended):
		car.drift_ended.connect(_on_car_drift_ended)
	if not car.body_entered.is_connected(_on_car_body_entered):
		car.body_entered.connect(_on_car_body_entered)

	if _engine_player and not _engine_player.playing:
		_engine_player.play()
	_update_engine_state()


func _ensure_players() -> void:
	if _crash_player == null:
		_crash_player = _make_player(
			CRASH_PLAYER_NAME,
			crash_stream,
			_placeholder_audio.build_crash_stream(),
			CRASH_VOLUME_DB
		)
	if _drift_player == null:
		_drift_player = _make_player(
			DRIFT_PLAYER_NAME,
			drift_stream,
			_placeholder_audio.build_drift_stream(),
			DRIFT_VOLUME_DB
		)
	if _engine_player == null:
		_engine_player = _make_player(
			ENGINE_PLAYER_NAME,
			engine_stream,
			_placeholder_audio.build_engine_stream(),
			ENGINE_IDLE_VOLUME_DB
		)


func _make_player(player_name: String, assigned_stream: AudioStream, fallback_stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.stream = assigned_stream if assigned_stream != null else fallback_stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _on_car_body_entered(_body: Node) -> void:
	if _time_since_last_crash < CRASH_RETRIGGER_SECONDS:
		return
	if car == null or _crash_player == null:
		return
	if car.linear_velocity.length() < CRASH_MIN_SPEED:
		return
	_time_since_last_crash = 0.0
	_crash_player.pitch_scale = randf_range(0.9, 1.1)
	_crash_player.play()


func _on_car_drift_started() -> void:
	if _drift_player and not _drift_player.playing:
		_drift_player.play()


func _on_car_drift_ended() -> void:
	if _drift_player:
		_drift_player.stop()


func _update_engine_state() -> void:
	if car == null or _engine_player == null:
		return
	var throttle_magnitude: float = clampf(absf(car.throttle_input), 0.0, 1.0)
	_engine_player.pitch_scale = lerpf(ENGINE_IDLE_PITCH, ENGINE_MAX_PITCH, throttle_magnitude)
	_engine_player.volume_db = lerpf(ENGINE_IDLE_VOLUME_DB, ENGINE_FULL_VOLUME_DB, throttle_magnitude)


func _disconnect_car_signals() -> void:
	if not is_instance_valid(car):
		return
	if car.drift_started.is_connected(_on_car_drift_started):
		car.drift_started.disconnect(_on_car_drift_started)
	if car.drift_ended.is_connected(_on_car_drift_ended):
		car.drift_ended.disconnect(_on_car_drift_ended)
	if car.body_entered.is_connected(_on_car_body_entered):
		car.body_entered.disconnect(_on_car_body_entered)


func _release_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	player.stop()
	player.stream = null
