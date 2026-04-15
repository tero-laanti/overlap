class_name SurfaceProfile
extends Resource

@export var display_name: String = "Surface"

@export_group("Speed")
@export var acceleration_multiplier: float = 1.0
@export var max_speed_multiplier: float = 1.0
@export var drift_boost_multiplier: float = 1.0

@export_group("Handling")
@export var turn_speed_multiplier: float = 1.0
@export var grip_multiplier: float = 1.0
@export var drift_grip_multiplier: float = 1.0
@export var drift_threshold_multiplier: float = 1.0

@export_group("Physics")
@export var linear_drag_multiplier: float = 1.0
