class_name CarStats
extends Resource

@export_group("Speed")
@export var max_speed := 25.0
@export var acceleration_force := 40.0
@export var brake_force := 60.0
@export var reverse_max_speed := 10.0

@export_group("Handling")
@export var turn_speed := 3.5
@export var grip := 8.0 ## How quickly lateral velocity is killed (higher = more grip)
@export var drift_grip := 2.0 ## Grip during drift (lower = more slide)
@export var drift_threshold := 4.0 ## Lateral speed to trigger drift state
@export var drift_min_speed := 8.0 ## Must be going this fast to drift

@export_group("Drift")
@export var drift_boost_force := 5.0 ## Extra forward force while drifting (the Big Lie)

@export_group("Physics")
@export var linear_drag := 0.5 ## Slows the car when coasting
