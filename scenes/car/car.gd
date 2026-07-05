class_name Car
extends CharacterBody2D
## Arcade top-down car. Velocity is split into forward and lateral
## components each tick; lateral speed bleeds off by grip, so lowering grip
## = drifting. The sprite points up (-Y), so forward is -transform.y.
## Physics reads effective stats: the base CarStats resource multiplied by
## owned upgrades. The base resource is never mutated.

const CarStatsScript = preload("res://scenes/car/car_stats.gd")
const REAR_LEFT_TIRE := Vector2(-14.0, 24.0)
const REAR_RIGHT_TIRE := Vector2(14.0, 24.0)

@export var stats: CarStatsScript

var _fx: CarStatsScript
var _left_trail: Line2D
var _right_trail: Line2D
var _left_trail_last := Vector2.ZERO
var _right_trail_last := Vector2.ZERO
var _trails_active := false


func _ready() -> void:
	_refresh_stats()
	Events.upgrade_purchased.connect(func(_id: String, _level: int) -> void:
		_refresh_stats())


func effective_stats() -> CarStatsScript:
	return _fx


func _refresh_stats() -> void:
	_fx = stats.duplicate()
	for id: String in Bank.upgrade_levels:
		var def := Bank.CATALOG.find(id)
		var level: int = Bank.upgrade_levels[id]
		if def == null or level <= 0 or def.stat.is_empty():
			continue
		_fx.set(def.stat, float(_fx.get(def.stat)) * pow(def.effect_multiplier, level))


func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("brake", "accelerate")
	var steer := Input.get_axis("steer_left", "steer_right")
	var drifting := Input.is_action_pressed("drift")

	var forward := -transform.y
	var forward_speed := velocity.dot(forward)

	_apply_steering(steer, throttle, forward_speed, delta)

	# Re-split velocity against the new heading.
	forward = -transform.y
	forward_speed = velocity.dot(forward)
	var lateral := velocity - forward * forward_speed

	forward_speed = _apply_throttle(throttle, forward_speed, delta)
	forward_speed = clampf(forward_speed, -_fx.reverse_speed, _fx.max_speed)

	var grip := _fx.drift_grip if drifting else _fx.grip
	var lateral_speed := lateral.length()
	lateral *= exp(-grip * delta)

	velocity = forward * forward_speed + lateral
	move_and_slide()
	_update_drift_trails(drifting, lateral_speed, velocity.length())


func _apply_steering(steer: float, throttle: float, forward_speed: float, delta: float) -> void:
	if is_zero_approx(steer):
		return
	var authority := clampf(absf(forward_speed) / _fx.steering_full_speed, 0.0, 1.0)
	if absf(forward_speed) > _fx.steering_floor_min_speed or not is_zero_approx(throttle):
		authority = maxf(authority, _fx.steering_authority_floor)
	if is_zero_approx(authority):
		return
	# signf flips steering while reversing, like a real car.
	var direction := signf(forward_speed) if not is_zero_approx(forward_speed) else signf(throttle)
	var turn := deg_to_rad(_fx.steering_rate) * steer * authority * direction
	rotation += turn * delta


func _apply_throttle(throttle: float, forward_speed: float, delta: float) -> float:
	if throttle > 0.0:
		return forward_speed + _fx.acceleration * throttle * delta
	if throttle < 0.0:
		var rate := _fx.braking if forward_speed > 0.0 else _fx.acceleration
		return forward_speed + rate * throttle * delta
	return move_toward(forward_speed, 0.0, _fx.rolling_drag * delta)


func _make_trail() -> Line2D:
	var line := Line2D.new()
	line.name = "DriftTrail"
	line.top_level = true
	line.global_position = Vector2.ZERO
	line.width = _fx.drift_trail_width
	line.default_color = Color(0.01, 0.012, 0.014, 0.9)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var container := get_parent()
	container.add_child(line)
	container.move_child(line, get_index())
	return line


## A finished trail stays behind at full strength, then fades and frees
## itself. Each drift stint gets fresh Line2D nodes — reusing one would
## draw a connecting segment from wherever the previous stint ended.
func _retire_trail(line: Line2D) -> void:
	if line == null:
		return
	if line.get_point_count() < 2:
		line.queue_free()
		return
	var tween := line.create_tween()
	tween.tween_interval(_fx.drift_trail_fade_delay)
	tween.tween_property(line, "modulate:a", 0.0, _fx.drift_trail_fade_time)
	tween.tween_callback(line.queue_free)


func _update_drift_trails(drifting: bool, lateral_speed: float, speed: float) -> void:
	var sliding := lateral_speed >= _fx.drift_trail_min_lateral_speed
	var should_draw := sliding or (drifting and speed >= _fx.drift_trail_min_speed)
	if not should_draw:
		if _trails_active:
			_retire_trail(_left_trail)
			_retire_trail(_right_trail)
			_left_trail = null
			_right_trail = null
			_trails_active = false
		return
	if not _trails_active:
		if get_parent() == null:
			return
		_left_trail = _make_trail()
		_right_trail = _make_trail()
		_left_trail_last = to_global(REAR_LEFT_TIRE)
		_right_trail_last = to_global(REAR_RIGHT_TIRE)
		_trails_active = true
	var left := to_global(REAR_LEFT_TIRE)
	var right := to_global(REAR_RIGHT_TIRE)
	if _add_trail_point(_left_trail, left, _left_trail_last):
		_left_trail_last = left
	if _add_trail_point(_right_trail, right, _right_trail_last):
		_right_trail_last = right


func _add_trail_point(line: Line2D, point: Vector2, previous: Vector2) -> bool:
	if line.get_point_count() > 0 and point.distance_to(previous) < _fx.drift_trail_spacing:
		return false
	line.add_point(point)
	while line.get_point_count() > _fx.drift_trail_max_points:
		line.remove_point(0)
	return true
