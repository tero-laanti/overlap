@tool
class_name TrackDirection
extends RefCounted

enum Heading {
	N,
	NE,
	E,
	SE,
	S,
	SW,
	W,
	NW,
}

const _BOUNDARY_POINTS := {
	Heading.N: Vector3(0.0, 0.0, -0.5),
	Heading.NE: Vector3(0.5, 0.0, -0.5),
	Heading.E: Vector3(0.5, 0.0, 0.0),
	Heading.SE: Vector3(0.5, 0.0, 0.5),
	Heading.S: Vector3(0.0, 0.0, 0.5),
	Heading.SW: Vector3(-0.5, 0.0, 0.5),
	Heading.W: Vector3(-0.5, 0.0, 0.0),
	Heading.NW: Vector3(-0.5, 0.0, -0.5),
}

const _GRID_OFFSETS := {
	Heading.N: Vector2i(0, -1),
	Heading.NE: Vector2i(1, -1),
	Heading.E: Vector2i(1, 0),
	Heading.SE: Vector2i(1, 1),
	Heading.S: Vector2i(0, 1),
	Heading.SW: Vector2i(-1, 1),
	Heading.W: Vector2i(-1, 0),
	Heading.NW: Vector2i(-1, -1),
}

const _LABELS := {
	Heading.N: "N",
	Heading.NE: "NE",
	Heading.E: "E",
	Heading.SE: "SE",
	Heading.S: "S",
	Heading.SW: "SW",
	Heading.W: "W",
	Heading.NW: "NW",
}


static func wrap_direction(direction: int) -> int:
	return wrapi(direction, 0, Heading.size())


static func rotate(direction: int, rotation_steps: int) -> int:
	return wrap_direction(direction + rotation_steps)


static func opposite(direction: int) -> int:
	return rotate(direction, 4)


static func are_opposites(first_direction: int, second_direction: int) -> bool:
	return opposite(first_direction) == wrap_direction(second_direction)


static func get_boundary_point(direction: int) -> Vector3:
	return _BOUNDARY_POINTS.get(wrap_direction(direction), Vector3.ZERO)


static func get_grid_offset(direction: int) -> Vector2i:
	return _GRID_OFFSETS.get(wrap_direction(direction), Vector2i.ZERO)


static func get_label(direction: int) -> String:
	return _LABELS.get(wrap_direction(direction), "?")
