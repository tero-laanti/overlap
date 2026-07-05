class_name CarStats
extends Resource
## Handling and performance tuning for one car. Authored as .tres files in
## data/cars/ — tune there, not in code.

@export var max_speed := 900.0
@export var reverse_speed := 280.0
@export var acceleration := 800.0
@export var braking := 1600.0
@export var rolling_drag := 300.0
## Lateral velocity bleed per second (higher = grippier). Applied as
## exp(-grip * delta), so it is frame-rate independent.
@export_range(0.0, 20.0) var grip := 9.0
## Grip while the drift (handbrake) action is held.
@export_range(0.0, 20.0) var drift_grip := 2.2
## Degrees per second at full steering authority.
@export var steering_rate := 200.0
## Forward speed at which steering reaches full authority.
@export var steering_full_speed := 250.0
