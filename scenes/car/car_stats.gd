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
## Minimum steering authority when throttle/brake is held, even at low speed.
@export_range(0.0, 1.0) var steering_authority_floor := 0.35
## Speed above which the steering authority floor applies without throttle.
@export var steering_floor_min_speed := 20.0
## Minimum vehicle speed before held drift draws tire trails.
@export var drift_trail_min_speed := 140.0
## Minimum sideways speed that draws tire scrub even without the drift key.
@export var drift_trail_min_lateral_speed := 250.0
## World-space distance between trail points.
@export var drift_trail_spacing := 8.0
@export var drift_trail_max_points := 180
@export var drift_trail_width := 7.0
## Seconds a finished trail stays at full strength before fading.
@export var drift_trail_fade_delay := 4.0
## Seconds the fade-out itself takes.
@export var drift_trail_fade_time := 1.5
## Fraction of max_speed the car can sustain off the road.
@export_range(0.05, 1.0) var grass_speed_multiplier := 0.5
## How fast excess speed bleeds off on grass, in px/s².
@export var grass_deceleration := 1100.0
## Fraction of max_speed the car can sustain on rubble strips (near-stop).
@export_range(0.02, 1.0) var rubble_speed_multiplier := 0.12
## How fast excess speed bleeds off on rubble, in px/s².
@export var rubble_deceleration := 2600.0
