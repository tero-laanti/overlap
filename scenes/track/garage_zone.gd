extends Node2D
## The spot in front of the GARAGE building where the shop can open.
## Pure geometry in the "garage_zone" group — the shop and HUD poll
## contains() against the car; no signals, no state.

@export var radius := 360.0


func _ready() -> void:
	add_to_group("garage_zone")


func contains(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos) <= radius
