class_name CarAudio
extends Node

## Plays sound for the three events the car emits: wall contacts (crashes),
## drift entry/exit, and throttle (the engine loop). Each slot accepts a
## supplied AudioStream; when left empty, a placeholder WAV is synthesized at
## ready-time so the prototype always has audible feedback.

const SAMPLE_RATE := 22050
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


func _ready() -> void:
	if car != null:
		bind_car(car)


func _process(delta: float) -> void:
	_time_since_last_crash += delta
	_update_engine_state()


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
		_crash_player = _make_player(CRASH_PLAYER_NAME, crash_stream, _build_crash_stream(), CRASH_VOLUME_DB)
	if _drift_player == null:
		_drift_player = _make_player(DRIFT_PLAYER_NAME, drift_stream, _build_drift_stream(), DRIFT_VOLUME_DB)
	if _engine_player == null:
		_engine_player = _make_player(ENGINE_PLAYER_NAME, engine_stream, _build_engine_stream(), ENGINE_IDLE_VOLUME_DB)


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


func _build_crash_stream() -> AudioStreamWAV:
	var duration: float = 0.45
	var sample_count: int = int(duration * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / float(sample_count)
		var envelope: float = pow(1.0 - t, 2.5)
		var value: float = (randf() * 2.0 - 1.0) * envelope
		data.encode_s16(i * 2, clampi(int(value * 32767.0), -32767, 32767))
	return _make_wav(data, false)


func _build_drift_stream() -> AudioStreamWAV:
	var duration: float = 0.6
	var sample_count: int = int(duration * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var low_pass_state: float = 0.0
	for i in range(sample_count):
		var raw: float = randf() * 2.0 - 1.0
		low_pass_state = lerpf(low_pass_state, raw, 0.3)
		var value: float = low_pass_state * 0.75
		data.encode_s16(i * 2, clampi(int(value * 32767.0), -32767, 32767))
	return _make_wav(data, true)


func _build_engine_stream() -> AudioStreamWAV:
	var duration: float = 0.5
	var sample_count: int = int(duration * SAMPLE_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(sample_count * 2)
	var base_hz: float = 90.0
	for i in range(sample_count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var fundamental: float = sin(TAU * base_hz * t)
		var harmonic: float = 0.45 * sin(TAU * base_hz * 2.0 * t)
		var growl: float = 0.2 * sin(TAU * base_hz * 0.5 * t + sin(TAU * 14.0 * t))
		var value: float = clampf((fundamental + harmonic + growl) * 0.35, -1.0, 1.0)
		data.encode_s16(i * 2, clampi(int(value * 32767.0), -32767, 32767))
	return _make_wav(data, true)


func _make_wav(pcm: PackedByteArray, looping: bool) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.data = pcm
	stream.mix_rate = SAMPLE_RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = pcm.size() / 2
	return stream


func _disconnect_car_signals() -> void:
	if not is_instance_valid(car):
		return
	if car.drift_started.is_connected(_on_car_drift_started):
		car.drift_started.disconnect(_on_car_drift_started)
	if car.drift_ended.is_connected(_on_car_drift_ended):
		car.drift_ended.disconnect(_on_car_drift_ended)
	if car.body_entered.is_connected(_on_car_body_entered):
		car.body_entered.disconnect(_on_car_body_entered)
