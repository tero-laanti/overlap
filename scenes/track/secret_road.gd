class_name SecretRoad
extends Node2D
## A road that exists but isn't there yet. Wraps a RoadSegment child
## named Segment: invisible and undrivable (its surface hitbox disabled,
## so it reads as grass) until its secret is unlocked. The unlock
## trigger is a crossing line — Track routes RouteTracker.line_crossed
## here — so discovery happens by driving, never by menu. Unlocked
## state lives in Bank and survives restarts.

@export var secret_id := ""
@export var trigger_line_id := ""

@onready var _segment: Node2D = $Segment
@onready var _hitbox: CollisionPolygon2D = $Segment/SurfaceArea/Hitbox


func _ready() -> void:
	Events.secret_unlocked.connect(func(id: String) -> void:
		if id == secret_id:
			_reveal(true))
	if Bank.is_secret_unlocked(secret_id):
		_reveal(false)
	else:
		_segment.visible = false
		_hitbox.set_deferred("disabled", true)


func on_line_crossed(line_id: String, forward: bool) -> void:
	if line_id == trigger_line_id and forward \
			and not Bank.is_secret_unlocked(secret_id):
		Bank.unlock_secret(secret_id)


func _reveal(animate: bool) -> void:
	_segment.visible = true
	_hitbox.set_deferred("disabled", false)
	if animate:
		_segment.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_segment, "modulate:a", 1.0, 1.2)
