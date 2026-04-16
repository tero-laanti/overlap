class_name HazardType
extends RefCounted

enum Type {
	OIL_SLICK,
	WALL_BARRIER,
	SLOW_ZONE,
}

const NONE := -1

const SCENE_PATHS := {
	Type.OIL_SLICK: "res://race/hazards/oil_slick.tscn",
	Type.WALL_BARRIER: "res://race/hazards/wall_barrier.tscn",
	Type.SLOW_ZONE: "res://race/hazards/slow_zone.tscn",
}

const DISPLAY_NAMES := {
	Type.OIL_SLICK: "Oil Slick",
	Type.WALL_BARRIER: "Wall Barrier",
	Type.SLOW_ZONE: "Slow Zone",
}

const DESCRIPTIONS := {
	Type.OIL_SLICK: "Grip collapses for 1.5s after you pass through it.",
	Type.WALL_BARRIER: "A solid blocker that throws the car back on impact.",
	Type.SLOW_ZONE: "Caps your speed while you drive through it.",
}

const NODE_NAMES := {
	Type.OIL_SLICK: "OilSlick",
	Type.WALL_BARRIER: "WallBarrier",
	Type.SLOW_ZONE: "SlowZone",
}


static func get_available_types() -> Array[int]:
	return [
		Type.OIL_SLICK,
		Type.WALL_BARRIER,
		Type.SLOW_ZONE,
	]


static func is_valid_type(hazard_type: int) -> bool:
	return SCENE_PATHS.has(hazard_type)


static func get_scene_path(hazard_type: int) -> String:
	return SCENE_PATHS.get(hazard_type, "")


static func get_display_name(hazard_type: int) -> String:
	return DISPLAY_NAMES.get(hazard_type, "Unknown Hazard")


static func get_description(hazard_type: int) -> String:
	return DESCRIPTIONS.get(hazard_type, "No description available.")


static func get_node_name(hazard_type: int) -> String:
	return NODE_NAMES.get(hazard_type, "Hazard")
