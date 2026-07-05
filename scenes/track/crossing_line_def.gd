class_name CrossingLineDef
extends Resource
## One directed crossing line in the track network. The car's per-tick
## movement segment is tested against (a, b); the sign of the cross
## product gives direction. Author (a, b) so that crossing in the race
## direction is positive.

@export var id := ""
@export var a := Vector2.ZERO
@export var b := Vector2.ZERO
