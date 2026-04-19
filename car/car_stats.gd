class_name CarStats
extends Resource

@export_group("Speed")
@export var max_speed: float = 30.0
@export var acceleration_force: float = 50
@export var brake_force: float = 72.0
@export var reverse_max_speed: float = 10.0
@export_range(0.1, 1.0, 0.01) var reverse_acceleration_factor: float = 0.55

@export_group("Handling")
@export var turn_speed: float = 3.4
@export var steering_response: float = 16.0
@export var air_steering_response: float = 10.0
@export var speed_for_full_turn: float = 6.0
@export var grip: float = 10.0 ## How quickly lateral velocity is redirected back under the car.
@export var drift_grip: float = 1.5 ## Lower grip keeps the arcade drift sliding.
@export var drift_grip_recovery_duration: float = 0.25 ## Seconds to ease lateral grip from `drift_grip` back to `grip` after a drift ends. Keeps the exit from snapping laterally.
@export var drift_threshold: float = 3.0 ## Entry threshold for the steering + slip drift metric.
@export var drift_min_speed: float = 7.5
@export var drift_turn_multiplier: float = 1.15
@export var air_steer_factor: float = 0.5

@export_group("Drift")
@export var drift_boost_force: float = 8.0 ## Extra forward force while drifting.

@export_group("Physics")
@export var linear_drag: float = 0.7 ## Slows the car when coasting on the ground.
@export var air_drag: float = 0.08
@export var ground_stick_force: float = 10.0
@export var uphill_acceleration_bonus: float = 0.45
@export var ground_probe_start_height: float = 0.45
@export var ground_probe_length: float = 1.1
@export var grounded_probe_distance: float = 0.8

@export_group("Proxy")
@export var proxy_radius: float = 0.65
@export var proxy_center_height: float = 0.4
@export var proxy_angular_damp: float = 2.8
