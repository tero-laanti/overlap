class_name FollowCamera
extends Camera2D
## Speed-reactive follow camera: zooms out toward top speed so fast
## driving shows more road, and shakes on splashes and hard wall hits.
## Purely visual — reads the car, never writes to it.

const CarScript = preload("res://scenes/car/car.gd")

@export var base_zoom := 0.6
@export var top_speed_zoom := 0.51
@export var zoom_lerp_speed := 2.5
@export var shake_decay := 7.0
@export var splash_shake := 12.0

var _shake := 0.0

@onready var _car: CarScript = get_parent()


func _ready() -> void:
	Events.car_reset_to_road.connect(func() -> void: bump(splash_shake))


## Physics process to match the camera's interpolation mode.
func _physics_process(delta: float) -> void:
	var max_speed: float = _car.effective_stats().max_speed
	var speed_fraction := clampf(_car.velocity.length() / max_speed, 0.0, 1.0)
	var target := lerpf(base_zoom, top_speed_zoom, speed_fraction)
	var zoomed := lerpf(zoom.x, target, 1.0 - exp(-zoom_lerp_speed * delta))
	zoom = Vector2(zoomed, zoomed)
	if _shake > 0.1:
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		_shake *= exp(-shake_decay * delta)
	else:
		offset = Vector2.ZERO


func bump(amount: float) -> void:
	_shake = maxf(_shake, amount)
