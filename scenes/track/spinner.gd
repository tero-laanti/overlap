extends Node2D
## Constant rotation — the lighthouse lamp beam sweep.

@export var speed := 0.5


func _process(delta: float) -> void:
	rotation += speed * delta
