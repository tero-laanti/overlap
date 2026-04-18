class_name CarAudioPlaceholder
extends RefCounted

## Owns the synthesized fallback audio streams used when the prototype has
## no imported assets yet. Keeping this separate lets `CarAudio` stay focused
## on car-signal wiring and playback state.

const SAMPLE_RATE := 22050


func build_crash_stream() -> AudioStreamWAV:
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


func build_drift_stream() -> AudioStreamWAV:
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


func build_engine_stream() -> AudioStreamWAV:
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
		# `pcm` is a byte buffer of 16-bit samples; loop_end is in samples.
		@warning_ignore("integer_division")
		stream.loop_end = pcm.size() / 2
	return stream
