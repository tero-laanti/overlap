class_name SphereCarValidator
extends SceneTree

## Smoke test for the Kenney sphere-vehicle controller (`SphereCar`). The
## sphere model does not participate in most of the legacy invariants
## (drift state machine, surface speed profiles, heading reconciliation,
## visual pitch lean), so validation is narrow: does a freshly-spawned
## `main.tscn` boot, does the car respond to throttle, and does it travel
## a reasonable distance in a few physics seconds?

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const SLOW_ZONE_SCENE: PackedScene = preload("res://race/hazards/slow_zone.tscn")
const GRAVEL_SPILL_SCENE: PackedScene = preload("res://race/hazards/gravel_spill.tscn")
const WASH_GATE_SCENE: PackedScene = preload("res://race/wash_gate.tscn")
## Any layout without a `preferred_vehicle` override. The auto-swap would hide
## the plain `main.tscn` default if we pointed at a layout that force-selected
## a different controller.
const RECTANGLE_LAYOUT_INDEX := 0
const EXTRA_ROUND_TIME := 120.0
const TEST_DURATION_SEC := 3.0
const MINIMUM_TRAVEL := 10.0
const CAR_SPAWN_Y_OFFSET := 0.37

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var game_session: Node = root.get_node_or_null(^"GameSession")
	if game_session != null:
		game_session.selected_track_index = RECTANGLE_LAYOUT_INDEX
	var scene: Node3D = MAIN_SCENE.instantiate()
	root.add_child(scene)
	await _await_physics_frames(2)

	var car: Car = scene.get_node_or_null(^"Car") as Car
	var track: TestTrack = scene.get_node_or_null(^"Track") as TestTrack
	var run_state: RunState = scene.get_node_or_null(^"RunState") as RunState
	if car == null or track == null:
		_fail("main.tscn missing Car or Track")
		_finish(scene)
		return
	if run_state == null:
		_fail("main.tscn missing RunState")
		_finish(scene)
		return
	if not (car is SphereCar):
		_fail("main.tscn Car is not a SphereCar instance (got %s)" % car.get_class())

	run_state.reset_for_new_run()
	run_state.start_round(EXTRA_ROUND_TIME)
	await _await_physics_frames(1)
	car.reset_to_transform(track.get_start_transform(CAR_SPAWN_Y_OFFSET))
	await _await_physics_frames(2)

	_check_reset_restores_visual_root(car as SphereCar, track)
	await _check_speed_cap_sources_and_wash_gate(scene, car as SphereCar)

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


## `_align_visual_to_ground` accumulates tilt on VisualRoot over a run.
## `reset_to_transform` must restore the rest transform so respawns look
## upright immediately rather than drifting back to level over ~10 ticks.
func _check_reset_restores_visual_root(car: SphereCar, track: TestTrack) -> void:
	var visual_root: Node3D = car.get_node_or_null(^"VisualRoot") as Node3D
	if visual_root == null:
		_fail("SphereCar has no VisualRoot child.")
		return
	var rest_basis: Basis = visual_root.transform.basis
	# Forge a tilted visual transform as if the car had been driving on a slope.
	visual_root.transform.basis = rest_basis.rotated(Vector3.FORWARD, deg_to_rad(25.0))
	car.reset_to_transform(track.get_start_transform(CAR_SPAWN_Y_OFFSET))
	var roll_after_reset: float = rad_to_deg(visual_root.transform.basis.get_euler().z)
	print("sphere car visual-root roll after reset: %.2f°" % roll_after_reset)
	if absf(roll_after_reset) > 0.5:
		_fail("SphereCar.reset_to_transform did not restore VisualRoot (roll %.2f°)." % roll_after_reset)


func _check_speed_cap_sources_and_wash_gate(scene: Node3D, car: SphereCar) -> void:
	var proxy: CarPhysicsProxy = car.get_physics_proxy()
	var slow_zone: SlowZone = SLOW_ZONE_SCENE.instantiate() as SlowZone
	var gravel: GravelSpill = GRAVEL_SPILL_SCENE.instantiate() as GravelSpill
	var wash_gate: WashGate = WASH_GATE_SCENE.instantiate() as WashGate
	scene.add_child(slow_zone)
	scene.add_child(gravel)
	scene.add_child(wash_gate)
	await _await_physics_frames(1)

	slow_zone._on_body_entered(proxy)
	if not is_equal_approx(car._speed_cap_factor, slow_zone.speed_factor):
		_fail("SphereCar SlowZone speed cap mismatch.")

	gravel._on_body_entered(proxy)
	var combined_speed_cap: float = minf(slow_zone.speed_factor, gravel.speed_factor)
	if not is_equal_approx(car._speed_cap_factor, combined_speed_cap):
		_fail("SphereCar overlapping slow hazards did not keep the tightest speed cap.")
	if not is_equal_approx(car._grip_modifier, gravel.grip_multiplier):
		_fail("SphereCar GravelSpill grip penalty mismatch.")

	wash_gate._on_body_entered(proxy)
	if not is_equal_approx(car._grip_modifier, 1.0):
		_fail("SphereCar WashGate did not clear the temporary grip modifier.")
	if not is_equal_approx(car._speed_cap_factor, combined_speed_cap):
		_fail("SphereCar WashGate should not clear active speed caps.")

	slow_zone._on_body_exited(proxy)
	if not is_equal_approx(car._speed_cap_factor, gravel.speed_factor):
		_fail("SphereCar exiting one slow hazard cleared the remaining speed cap.")

	gravel._on_body_exited(proxy)
	if not is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("SphereCar speed cap did not restore after all hazards exited.")

	print("sphere car speed caps and wash gate: ok")
	slow_zone.queue_free()
	gravel.queue_free()
	wash_gate.queue_free()
	await _await_physics_frames(1)


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
