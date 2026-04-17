class_name HazardType
extends RefCounted

enum Type {
	OIL_SLICK,
	WALL_BARRIER,
	SLOW_ZONE,
	CONE_CHICANE,
	GRAVEL_SPILL,
	CROSSWIND_FAN,
}

enum Category {
	LINE_TAX,
	HARD_REROUTE,
}

const NONE := -1

const SCENE_PATHS := {
	Type.OIL_SLICK: "res://race/hazards/oil_slick.tscn",
	Type.WALL_BARRIER: "res://race/hazards/wall_barrier.tscn",
	Type.SLOW_ZONE: "res://race/hazards/slow_zone.tscn",
	Type.CONE_CHICANE: "res://race/hazards/cone_chicane.tscn",
	Type.GRAVEL_SPILL: "res://race/hazards/gravel_spill.tscn",
	Type.CROSSWIND_FAN: "res://race/hazards/crosswind_fan.tscn",
}

const DISPLAY_NAMES := {
	Type.OIL_SLICK: "Oil Slick",
	Type.WALL_BARRIER: "Wall Barrier",
	Type.SLOW_ZONE: "Slow Zone",
	Type.CONE_CHICANE: "Cone Chicane",
	Type.GRAVEL_SPILL: "Gravel Spill",
	Type.CROSSWIND_FAN: "Crosswind Fan",
}

const DESCRIPTIONS := {
	Type.OIL_SLICK: "Grip collapses for 1.5s after you pass through it.",
	Type.WALL_BARRIER: "A solid blocker that throws the car back on impact.",
	Type.SLOW_ZONE: "Caps your speed while you drive through it.",
	Type.CONE_CHICANE: "Staggered blockers that turn a straight line into a slalom.",
	Type.GRAVEL_SPILL: "A mushy surface patch that bleeds speed and traction.",
	Type.CROSSWIND_FAN: "A lateral shove zone that pushes you off the easy line.",
}

const NODE_NAMES := {
	Type.OIL_SLICK: "OilSlick",
	Type.WALL_BARRIER: "WallBarrier",
	Type.SLOW_ZONE: "SlowZone",
	Type.CONE_CHICANE: "ConeChicane",
	Type.GRAVEL_SPILL: "GravelSpill",
	Type.CROSSWIND_FAN: "CrosswindFan",
}

const CATEGORIES := {
	Type.OIL_SLICK: Category.LINE_TAX,
	Type.WALL_BARRIER: Category.HARD_REROUTE,
	Type.SLOW_ZONE: Category.LINE_TAX,
	Type.CONE_CHICANE: Category.HARD_REROUTE,
	Type.GRAVEL_SPILL: Category.LINE_TAX,
	Type.CROSSWIND_FAN: Category.LINE_TAX,
}

const DRAFT_WEIGHTS := {
	Type.OIL_SLICK: 3,
	Type.WALL_BARRIER: 2,
	Type.SLOW_ZONE: 3,
	Type.CONE_CHICANE: 3,
	Type.GRAVEL_SPILL: 2,
	Type.CROSSWIND_FAN: 1,
}


static func get_available_types() -> Array[int]:
	return [
		Type.OIL_SLICK,
		Type.WALL_BARRIER,
		Type.SLOW_ZONE,
		Type.CONE_CHICANE,
		Type.GRAVEL_SPILL,
		Type.CROSSWIND_FAN,
	]


static func get_available_types_for_category(category: int) -> Array[int]:
	var filtered: Array[int] = []
	for hazard_type in get_available_types():
		if get_category(hazard_type) == category:
			filtered.append(hazard_type)
	return filtered


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


static func get_category(hazard_type: int) -> int:
	return CATEGORIES.get(hazard_type, Category.LINE_TAX)


static func get_draft_weight(hazard_type: int) -> int:
	return maxi(DRAFT_WEIGHTS.get(hazard_type, 1), 0)
