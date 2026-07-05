class_name LapRecording
extends Resource
## One validated lap: transform samples at a fixed rate, plus the lap time.
## The central artifact of the game — ghosts replay these, and the economy
## prices income off lap_time.

@export var sample_dt := 1.0 / 30.0
@export var positions := PackedVector2Array()
@export var rotations := PackedFloat32Array()
@export var lap_time := 0.0


## Interpolated transform at any elapsed time; loops forever. Time-based,
## not index-based, so playback survives frame drops and rate changes.
func transform_at(elapsed: float) -> Transform2D:
	var count := positions.size()
	if count == 0 or lap_time <= 0.0:
		return Transform2D.IDENTITY
	var t := fposmod(elapsed, lap_time)
	var exact := t / sample_dt
	var a := mini(int(exact), count - 1)
	var b := (a + 1) % count
	var frac := exact - float(int(exact))
	var pos := positions[a].lerp(positions[b], frac)
	var rot := lerp_angle(rotations[a], rotations[b], frac)
	return Transform2D(rot, pos)
