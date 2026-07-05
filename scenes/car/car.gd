class_name Car
extends CharacterBody2D
## Arcade top-down car. Velocity is split into forward and lateral components
## each tick; lateral speed bleeds off by grip, so lowering grip = drifting.
## The sprite points up (-Y), so forward is -transform.y.

@export var stats: CarStats


func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis("brake", "accelerate")
	var steer := Input.get_axis("steer_left", "steer_right")
	var drifting := Input.is_action_pressed("drift")

	var forward := -transform.y
	var forward_speed := velocity.dot(forward)

	_apply_steering(steer, forward_speed, delta)

	# Re-split velocity against the new heading.
	forward = -transform.y
	forward_speed = velocity.dot(forward)
	var lateral := velocity - forward * forward_speed

	forward_speed = _apply_throttle(throttle, forward_speed, delta)
	forward_speed = clampf(forward_speed, -stats.reverse_speed, stats.max_speed)

	var grip := stats.drift_grip if drifting else stats.grip
	lateral *= exp(-grip * delta)

	velocity = forward * forward_speed + lateral
	move_and_slide()


func _apply_steering(steer: float, forward_speed: float, delta: float) -> void:
	if is_zero_approx(steer) or is_zero_approx(forward_speed):
		return
	var authority := clampf(absf(forward_speed) / stats.steering_full_speed, 0.0, 1.0)
	# signf flips steering while reversing, like a real car.
	var turn := deg_to_rad(stats.steering_rate) * steer * authority * signf(forward_speed)
	rotation += turn * delta


func _apply_throttle(throttle: float, forward_speed: float, delta: float) -> float:
	if throttle > 0.0:
		return forward_speed + stats.acceleration * throttle * delta
	if throttle < 0.0:
		var rate := stats.braking if forward_speed > 0.0 else stats.acceleration
		return forward_speed + rate * throttle * delta
	return move_toward(forward_speed, 0.0, stats.rolling_drag * delta)
