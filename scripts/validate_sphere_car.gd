class_name SphereCarValidator
extends SceneTree

## Smoke test for the Kenney sphere-vehicle controller (`SphereCar`). The
## sphere model does not participate in most of the legacy invariants
## (drift state machine, surface speed profiles, heading reconciliation,
## visual pitch lean), so validation is narrow: does a freshly-spawned
## `main.tscn` boot, does the car respond to throttle, and does it travel
## a reasonable distance in a few physics seconds?

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const TEST_DURATION_SEC := 3.0
const MINIMUM_TRAVEL := 10.0
const CAR_SPAWN_Y_OFFSET := 0.37

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var scene: Node3D = MAIN_SCENE.instantiate()
	root.add_child(scene)
	await _await_physics_frames(2)

	var car: Car = scene.get_node_or_null(^"Car") as Car
	var track: TestTrack = scene.get_node_or_null(^"Track") as TestTrack
	if car == null or track == null:
		_fail("main.tscn missing Car or Track")
		_finish(scene)
		return
	if not (car is SphereCar):
		_fail("main.tscn Car is not a SphereCar instance (got %s)" % car.get_class())

	car.reset_to_transform(track.get_start_transform(CAR_SPAWN_Y_OFFSET))
	await _await_physics_frames(2)

	var start_position: Vector3 = car.global_position
	Input.action_press("throttle", 1.0)
	await _await_physics_frames(int(TEST_DURATION_SEC * float(Engine.physics_ticks_per_second)))
	Input.action_release("throttle")

	var travel_distance: float = car.global_position.distance_to(start_position)
	var top_speed: float = car.linear_velocity.length()
	print("sphere car smoke: travel=%.2fm, top_speed=%.2fm/s over %.1fs" % [travel_distance, top_speed, TEST_DURATION_SEC])
	if travel_distance < MINIMUM_TRAVEL:
		_fail("Sphere car travelled only %.2fm in %.1fs (expected ≥ %.1fm)" % [travel_distance, TEST_DURATION_SEC, MINIMUM_TRAVEL])
	if top_speed <= 0.5:
		_fail("Sphere car never built meaningful speed (final %.2f m/s)" % top_speed)

	_finish(scene)


func _finish(scene: Node) -> void:
	if scene != null:
		scene.queue_free()
	await _await_physics_frames(2)
	quit(1 if not _failures.is_empty() else 0)


func _await_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)
