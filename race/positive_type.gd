class_name PositiveType
extends RefCounted


enum Type {
	TIME_BANK,
	BOOST_PAD,
	COIN_GATE,
	DRIFT_RIBBON,
	WASH_GATE,
}

enum Category {
	UTILITY,
	GREED,
	HANDLING,
}

enum DeliveryMode {
	INSTANT,
	PLACEABLE,
	HAND,
}

const NONE := -1

const DISPLAY_NAMES := {
	Type.TIME_BANK: "Time Bank",
	Type.BOOST_PAD: "Boost Pad",
	Type.COIN_GATE: "Coin Gate",
	Type.DRIFT_RIBBON: "Drift Ribbon",
	Type.WASH_GATE: "Wash Gate",
}

const DESCRIPTIONS := {
	Type.TIME_BANK: "Permanently adds +5s to the run timer. Safe, expensive, and stacks forever.",
	Type.BOOST_PAD: "Place a pad that launches a good line into a faster one.",
	Type.COIN_GATE: "A narrow bonus gate. Thread the center once per lap for a cash spike.",
	Type.DRIFT_RIBBON: "Reward a committed drift line with extra carry and steadier slide control.",
	Type.WASH_GATE: "A clean-up gate that scrubs oil and slow effects when you pass through it.",
}

const BASE_COSTS := {
	Type.TIME_BANK: 20,
	Type.BOOST_PAD: 30,
	Type.COIN_GATE: 28,
	Type.DRIFT_RIBBON: 34,
	Type.WASH_GATE: 24,
}

const CATEGORIES := {
	Type.TIME_BANK: Category.UTILITY,
	Type.BOOST_PAD: Category.HANDLING,
	Type.COIN_GATE: Category.GREED,
	Type.DRIFT_RIBBON: Category.HANDLING,
	Type.WASH_GATE: Category.UTILITY,
}

const DELIVERY_MODES := {
	Type.TIME_BANK: DeliveryMode.INSTANT,
	Type.BOOST_PAD: DeliveryMode.PLACEABLE,
	Type.COIN_GATE: DeliveryMode.PLACEABLE,
	Type.DRIFT_RIBBON: DeliveryMode.PLACEABLE,
	Type.WASH_GATE: DeliveryMode.PLACEABLE,
}

const OFFER_WEIGHTS := {
	Type.TIME_BANK: 3,
	Type.BOOST_PAD: 3,
	Type.COIN_GATE: 1,
	Type.DRIFT_RIBBON: 2,
	Type.WASH_GATE: 2,
}

const SCENE_PATHS := {
	Type.BOOST_PAD: "res://race/boost_pad.tscn",
	Type.COIN_GATE: "res://race/coin_gate.tscn",
	Type.DRIFT_RIBBON: "res://race/drift_ribbon.tscn",
	Type.WASH_GATE: "res://race/wash_gate.tscn",
}

const NODE_NAMES := {
	Type.TIME_BANK: "TimeBank",
	Type.BOOST_PAD: "BoostPad",
	Type.COIN_GATE: "CoinGate",
	Type.DRIFT_RIBBON: "DriftRibbon",
	Type.WASH_GATE: "WashGate",
}


static func get_available_types() -> Array[int]:
	return [
		Type.TIME_BANK,
		Type.BOOST_PAD,
		Type.COIN_GATE,
		Type.DRIFT_RIBBON,
		Type.WASH_GATE,
	]


static func get_offer_categories() -> Array[int]:
	return [
		Category.UTILITY,
		Category.GREED,
		Category.HANDLING,
	]


static func get_available_types_for_category(category: int) -> Array[int]:
	var filtered: Array[int] = []
	for positive_type in get_available_types():
		if get_category(positive_type) == category:
			filtered.append(positive_type)
	return filtered


static func is_valid_type(positive_type: int) -> bool:
	return DISPLAY_NAMES.has(positive_type)


static func get_display_name(positive_type: int) -> String:
	return DISPLAY_NAMES.get(positive_type, "Unknown Positive")


static func get_description(positive_type: int) -> String:
	return DESCRIPTIONS.get(positive_type, "No description available.")


static func get_base_cost(positive_type: int) -> int:
	return BASE_COSTS.get(positive_type, 0)


static func get_category(positive_type: int) -> int:
	return CATEGORIES.get(positive_type, Category.UTILITY)


static func get_delivery_mode(positive_type: int) -> int:
	return DELIVERY_MODES.get(positive_type, DeliveryMode.PLACEABLE)


static func get_offer_weight(positive_type: int) -> int:
	return maxi(OFFER_WEIGHTS.get(positive_type, 1), 0)


static func get_scene_path(positive_type: int) -> String:
	return SCENE_PATHS.get(positive_type, "")


static func has_scene(positive_type: int) -> bool:
	return SCENE_PATHS.has(positive_type)


static func get_node_name(positive_type: int) -> String:
	return NODE_NAMES.get(positive_type, "Positive")
