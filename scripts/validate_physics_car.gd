class_name PhysicsCarValidator
extends SceneTree

## Validates the legacy integrator-based controller (`PhysicsCar`). Forces
## `main.tscn` to spawn with a `physics_car.tscn` in place of the default
## (`sphere_car.tscn`) so drift / heading / surface-speed expectations match
## the integrator model.

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const PHYSICS_CAR_SCENE: PackedScene = preload("res://car/physics_car.tscn")
const COIN_SCENE: PackedScene = preload("res://race/coin.tscn")
const BOOST_PAD_SCENE: PackedScene = preload("res://race/boost_pad.tscn")
const SLOW_ZONE_SCENE: PackedScene = preload("res://race/hazards/slow_zone.tscn")
const GRAVEL_SPILL_SCENE: PackedScene = preload("res://race/hazards/gravel_spill.tscn")
const SHUTTER_GATE_SCENE: PackedScene = preload("res://race/hazards/shutter_gate.tscn")
const WASH_GATE_SCENE: PackedScene = preload("res://race/wash_gate.tscn")

const RECTANGLE_LAYOUT_INDEX := 0
const EXTRA_ROUND_TIME := 120.0
const SURFACE_TEST_SECONDS := 2.0
const AUTOPILOT_TEST_SECONDS := 3.5
const DRIFT_TEST_SECONDS := 2.5
const CAR_SPAWN_Y_OFFSET := 0.37

var _failures: PackedStringArray = []
var _drift_started_count: int = 0


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	await _validate_flat_autopilot()
	await _validate_drift_and_jump()
	await _validate_surface_speeds()
	await _validate_reverse_throttle_release_no_flip()
	await _validate_collision_owner_resolution()
	await _validate_overlapping_speed_caps_and_wash_gate()
	await _validate_hazard_exit_cleanup_after_owner_cleared()
	await _validate_nested_shutter_gate_footprint_sampling()
	await _validate_reset_to_transform_grounded_state()

	_clear_drive_input()
	await _await_idle_and_physics()
	await _await_idle_and_physics()
	quit(1 if not _failures.is_empty() else 0)


func _validate_flat_autopilot() -> void:
	var flat_scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var flat_metrics: Dictionary = await _drive_with_autopilot(flat_scene, AUTOPILOT_TEST_SECONDS)
	print("flat metrics: %s" % flat_metrics)
	if float(flat_metrics.get("progress_delta", 0.0)) <= 0.035:
		_fail("Flat track autopilot did not make enough progress.")
	if int(flat_metrics.get("grounded_frames", 0)) <= int(flat_metrics.get("airborne_frames", 0)):
		_fail("Flat track spent too much time airborne.")
	await _free_scene(flat_scene)


func _validate_drift_and_jump() -> void:
	var drift_scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var drift_metrics: Dictionary = await _drive_for_drift(drift_scene, DRIFT_TEST_SECONDS)
	print("drift metrics: %s" % drift_metrics)
	if int(drift_metrics.get("drift_started_count", 0)) <= 0:
		_fail("Drift test never entered drift.")
	await _free_scene(drift_scene)
	# Jump-ramp sub-test was tied to `Track/JumpRamp`, a node removed from
	# `main.tscn` in bfc2d63. Reintroduce when a ramp track piece lands.


func _validate_surface_speeds() -> void:
	var surface_scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var track: TestTrack = _get_track(surface_scene)
	var car: Car = _get_car(surface_scene)
	var center_speed: float = await _measure_surface_speed(surface_scene, 0.0, SURFACE_TEST_SECONDS)
	var sand_offset: float = track.track_width * 0.5 + track.sand_width * 0.5
	var grass_offset: float = track.track_width * 0.5 + track.sand_width + 2.0
	var sand_speed: float = await _measure_surface_speed(surface_scene, sand_offset, SURFACE_TEST_SECONDS)
	var grass_speed: float = await _measure_surface_speed(surface_scene, grass_offset, SURFACE_TEST_SECONDS)
	print("surface speeds: tarmac=%.2f sand=%.2f grass=%.2f" % [center_speed, sand_speed, grass_speed])

	if sand_speed >= center_speed:
		_fail("Sand did not slow the car below tarmac pace.")
	if grass_speed >= center_speed:
		_fail("Grass did not slow the car below tarmac pace.")
	if sand_speed <= 3.0:
		_fail("Sand slowed the car too much; it effectively stalled.")
	if grass_speed <= 2.0:
		_fail("Grass slowed the car too much; it effectively stalled.")
	if car.global_position.y < -1.0:
		_fail("Surface-speed test left the car below the track.")
	await _free_scene(surface_scene)


func _validate_reverse_throttle_release_no_flip() -> void:
	var scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var car: Car = _get_car(scene)
	var initial_heading: Vector3 = _flat_forward(car)

	_apply_drive_input(-1.0, 0.0)
	await _await_physics_frames(int(float(Engine.physics_ticks_per_second) * 1.5))

	var planar_velocity: Vector3 = car.linear_velocity.slide(Vector3.UP)
	var reversing_speed: float = planar_velocity.length()
	var reverse_alignment: float = planar_velocity.normalized().dot(initial_heading) if reversing_speed > 0.001 else 0.0
	print("reverse setup: speed=%.2f alignment=%.2f" % [reversing_speed, reverse_alignment])
	if reversing_speed <= 2.0 or reverse_alignment >= -0.5:
		_fail("Reverse-flip test could not build sustained backward motion.")

	_clear_drive_input()
	# Observe past `REVERSE_INTENT_RETENTION_DURATION` so a fix that just
	# delays the flip by 0.5s cannot pass the test.
	await _await_physics_frames(int(float(Engine.physics_ticks_per_second) * 1.5))
	var released_heading: Vector3 = _flat_forward(car)
	var heading_delta_deg: float = rad_to_deg(initial_heading.angle_to(released_heading))
	print("reverse release heading delta: %.2f°" % heading_delta_deg)
	if heading_delta_deg >= 25.0:
		_fail("Heading flipped after releasing reverse throttle mid-reverse.")

	await _free_scene(scene)


func _validate_collision_owner_resolution() -> void:
	var scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var car: Car = _get_car(scene)
	var run_state: RunState = _get_run_state(scene)
	var proxy: CarPhysicsProxy = car.get_physics_proxy()
	if CarBodyResolver.resolve(proxy) != car:
		_fail("CarBodyResolver did not map the physics proxy back to Car.")

	var starting_currency: int = run_state.currency
	var coin: Coin = COIN_SCENE.instantiate() as Coin
	scene.add_child(coin)
	await _await_physics_frames(1)
	coin._on_body_entered(proxy)
	if run_state.currency <= starting_currency:
		_fail("Coin did not reward currency when entered by the proxy body.")
	coin.queue_free()
	await _await_idle_and_physics()

	var boost_pad: BoostPad = BOOST_PAD_SCENE.instantiate() as BoostPad
	scene.add_child(boost_pad)
	await _await_physics_frames(1)
	car.linear_velocity = Vector3.ZERO
	boost_pad._on_body_entered(proxy)
	if car.linear_velocity.length() <= 0.5:
		_fail("Boost pad did not affect the car when entered by the proxy body.")
	boost_pad.queue_free()
	await _free_scene(scene)


func _validate_hazard_exit_cleanup_after_owner_cleared() -> void:
	var scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var car: Car = _get_car(scene)
	var proxy: CarPhysicsProxy = car.get_physics_proxy()

	var slow_zone: SlowZone = SLOW_ZONE_SCENE.instantiate() as SlowZone
	scene.add_child(slow_zone)
	await _await_physics_frames(1)

	slow_zone.set_preview_mode(true)
	slow_zone._on_body_entered(proxy)
	if not slow_zone._active_cars.is_empty():
		_fail("SlowZone should ignore entry while in preview mode.")
	if not is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("SlowZone should not apply a speed cap while in preview mode.")
	slow_zone.set_preview_mode(false)

	slow_zone._on_body_entered(proxy)
	if slow_zone._active_cars.is_empty():
		_fail("SlowZone did not register the car when entered.")
	if is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("SlowZone did not apply a speed cap on entry.")

	proxy.bind_car(null)
	if CarBodyResolver.resolve(proxy) != null:
		_fail("CarBodyResolver should return null when proxy.car_owner is cleared.")
	slow_zone._on_body_exited(proxy)
	if not slow_zone._active_cars.is_empty():
		_fail("SlowZone did not clear _active_cars after exit once car_owner was nulled.")
	if not is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("SlowZone did not restore the speed cap after exit once car_owner was nulled.")
	print("slow-zone orphaned-exit cleanup: ok")
	proxy.bind_car(car)
	slow_zone.queue_free()
	await _await_idle_and_physics()

	var gravel: GravelSpill = GRAVEL_SPILL_SCENE.instantiate() as GravelSpill
	scene.add_child(gravel)
	await _await_physics_frames(1)
	gravel._on_body_entered(proxy)
	if gravel._active_cars.is_empty():
		_fail("GravelSpill did not register the car when entered.")
	if is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("GravelSpill did not apply a speed cap on entry.")

	proxy.bind_car(null)
	gravel._on_body_exited(proxy)
	if not gravel._active_cars.is_empty():
		_fail("GravelSpill did not clear _active_cars after exit once car_owner was nulled.")
	if not is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("GravelSpill did not restore the speed cap after exit once car_owner was nulled.")
	print("gravel-spill orphaned-exit cleanup: ok")
	proxy.bind_car(car)
	gravel.queue_free()
	await _free_scene(scene)


func _validate_overlapping_speed_caps_and_wash_gate() -> void:
	var scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var car: Car = _get_car(scene)
	if car == null:
		_fail("Speed-cap validator could not resolve the spawned car.")
		await _free_scene(scene)
		return
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
		_fail("SlowZone did not set the expected speed cap factor.")

	gravel._on_body_entered(proxy)
	var combined_speed_cap: float = minf(slow_zone.speed_factor, gravel.speed_factor)
	if not is_equal_approx(car._speed_cap_factor, combined_speed_cap):
		_fail("Overlapping slow hazards did not keep the most restrictive speed cap.")
	var grip_modifier: float = _get_temporary_grip_modifier(car)
	if not is_equal_approx(grip_modifier, gravel.grip_multiplier):
		_fail("GravelSpill did not apply its grip penalty on entry.")

	wash_gate._on_body_entered(proxy)
	grip_modifier = _get_temporary_grip_modifier(car)
	if not is_equal_approx(grip_modifier, 1.0):
		_fail("WashGate did not clear the temporary grip modifier.")
	if not is_equal_approx(car._speed_cap_factor, combined_speed_cap):
		_fail("WashGate should not clear active speed caps.")

	slow_zone._on_body_exited(proxy)
	if not is_equal_approx(car._speed_cap_factor, gravel.speed_factor):
		_fail("Exiting one slow hazard cleared the remaining active speed cap.")

	gravel._on_body_exited(proxy)
	if not is_equal_approx(car._speed_cap_factor, 1.0):
		_fail("Speed cap did not restore after all slow hazards exited.")
	print("overlapping speed caps and wash gate: ok")

	await _free_scene(scene)


func _validate_nested_shutter_gate_footprint_sampling() -> void:
	var scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var track: TestTrack = _get_track(scene)
	var hazard_root: Node3D = scene._hazard_controller.get_hazard_root()
	if track == null or hazard_root == null:
		_fail("ShutterGate footprint validator could not resolve the track or hazard root.")
		await _free_scene(scene)
		return

	var shutter_gate: ShutterGate = SHUTTER_GATE_SCENE.instantiate() as ShutterGate
	var boost_pad: BoostPad = BOOST_PAD_SCENE.instantiate() as BoostPad
	if shutter_gate == null or boost_pad == null:
		_fail("ShutterGate footprint validator could not instantiate the test scenes.")
		await _free_scene(scene)
		return

	var gate_transform: Transform3D = track.get_track_transform(track.get_lap_start_progress(), 0.0, 0.0)
	hazard_root.add_child(shutter_gate)
	shutter_gate.global_transform = gate_transform
	await _await_physics_frames(1)

	var overlapping_transform: Transform3D = gate_transform.translated_local(Vector3(2.4, 0.0, 0.0))
	var occupied_positions: Array[Vector3] = scene._get_occupied_track_item_positions()
	if scene._is_track_item_clear(boost_pad, overlapping_transform, occupied_positions):
		_fail("Nested ShutterGate collision shapes did not block an overlapping placement.")
	print("nested shutter-gate footprint sampling: ok")

	boost_pad.queue_free()
	shutter_gate.queue_free()
	await _free_scene(scene)


func _validate_reset_to_transform_grounded_state() -> void:
	var scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var car: Car = _get_car(scene)
	var track: TestTrack = _get_track(scene)

	car.reset_to_transform(track.get_start_transform(CAR_SPAWN_Y_OFFSET))
	# One physics tick applies the pending reset and runs `_update_ground_probe`
	# against the teleported proxy. A second tick is defensive slack.
	await _await_physics_frames(2)

	print("reset grounded: is_grounded=%s normal=%s" % [car.is_grounded, car.ground_normal])
	if not car.is_grounded:
		_fail("Car is not grounded on the physics tick after reset_to_transform.")
	if car.ground_normal.length_squared() < 0.9:
		_fail("Car ground_normal is not unit-length after reset_to_transform.")
	if car.ground_normal.dot(Vector3.UP) < 0.9:
		_fail("Car ground_normal is not near world UP after reset_to_transform on flat track.")

	await _free_scene(scene)


func _spawn_main_scene(track_index: int) -> MainSceneController:
	var scene: MainSceneController = MAIN_SCENE.instantiate() as MainSceneController
	_swap_in_physics_car(scene)
	root.add_child(scene)
	await _await_physics_frames(2)

	var track: TestTrack = _get_track(scene)
	var car: Car = _get_car(scene)
	var run_state: RunState = _get_run_state(scene)
	_disable_runtime_feedback(car)

	track.set_starter_layout_index(track_index)
	run_state.reset_for_new_run()
	run_state.start_round(EXTRA_ROUND_TIME)
	car.reset_to_transform(track.get_start_transform(CAR_SPAWN_Y_OFFSET))
	await _await_physics_frames(2)
	return scene


## Replaces the default Car child (loaded from `vehicle_scene` — currently
## `sphere_car.tscn`) with a freshly-instanced `physics_car.tscn` so this
## validator exercises the integrator-based model. Runs while the Main scene
## is still detached from the tree, so `_ready` fires only once for the
## resulting Car.
func _swap_in_physics_car(main_scene: Node) -> void:
	var old_car: Node3D = main_scene.get_node_or_null(^"Car") as Node3D
	if old_car == null:
		push_error("validate_physics_car: Main scene has no Car child to swap")
		return
	var spawn_transform: Transform3D = old_car.transform
	var sibling_index: int = old_car.get_index()
	main_scene.remove_child(old_car)
	# Detached nodes never enter the SceneTree, so `queue_free()` would never
	# flush and the validator would leak one orphaned car per scene spawn.
	old_car.free()

	var new_car: Node3D = PHYSICS_CAR_SCENE.instantiate() as Node3D
	new_car.name = "Car"
	new_car.transform = spawn_transform
	main_scene.add_child(new_car)
	main_scene.move_child(new_car, sibling_index)


func _free_scene(scene: Node) -> void:
	if scene != null:
		scene.queue_free()
	await _await_idle_and_physics()
	await _await_idle_and_physics()


func _drive_with_autopilot(scene: MainSceneController, duration: float) -> Dictionary:
	var car: Car = _get_car(scene)
	var track: TestTrack = _get_track(scene)
	var frame_count: int = int(duration * float(Engine.physics_ticks_per_second))
	var previous_progress: float = track.get_progress_at_position(car.global_position)
	var previous_position: Vector3 = car.global_position
	var total_progress: float = 0.0
	var travel_distance: float = 0.0
	var grounded_frames: int = 0
	var airborne_frames: int = 0
	var max_speed: float = 0.0
	var min_height: float = car.global_position.y

	for _frame in range(frame_count):
		var progress: float = track.get_progress_at_position(car.global_position)
		var speed: float = car.linear_velocity.slide(Vector3.UP).length()
		var lookahead: float = clampf(0.016 + speed * 0.0016, 0.016, 0.06)
		var target_transform: Transform3D = track.get_track_transform(wrapf(progress + lookahead, 0.0, 1.0), 0.0, 0.0)
		var target_vector: Vector3 = target_transform.origin - car.global_position
		target_vector.y = 0.0
		_apply_drive_input(1.0, _steer_toward(car, target_vector))
		await physics_frame
		if car.is_grounded:
			grounded_frames += 1
		else:
			airborne_frames += 1
		travel_distance += previous_position.distance_to(car.global_position)
		previous_position = car.global_position
		var progress_delta: float = _progress_delta(previous_progress, track.get_progress_at_position(car.global_position))
		total_progress += progress_delta
		previous_progress = track.get_progress_at_position(car.global_position)
		max_speed = maxf(max_speed, car.linear_velocity.slide(Vector3.UP).length())
		min_height = minf(min_height, car.global_position.y)

	_clear_drive_input()
	return {
		"progress_delta": total_progress,
		"grounded_frames": grounded_frames,
		"airborne_frames": airborne_frames,
		"max_speed": max_speed,
		"min_height": min_height,
		"travel_distance": travel_distance,
	}


func _drive_for_drift(scene: MainSceneController, duration: float) -> Dictionary:
	var car: Car = _get_car(scene)
	_drift_started_count = 0
	if not car.drift_started.is_connected(_on_validation_drift_started):
		car.drift_started.connect(_on_validation_drift_started)
	var frame_count: int = int(duration * float(Engine.physics_ticks_per_second))
	var drifting_frames: int = 0

	for frame_index in range(frame_count):
		var steer: float = 0.0 if frame_index < int(float(Engine.physics_ticks_per_second) * 0.8) else -1.0
		_apply_drive_input(1.0, steer)
		await physics_frame
		if car.is_drifting:
			drifting_frames += 1

	_clear_drive_input()
	return {
		"drift_started_count": _drift_started_count,
		"drifting_frames": drifting_frames,
	}


func _measure_surface_speed(scene: MainSceneController, lateral_offset: float, duration: float) -> float:
	var track: TestTrack = _get_track(scene)
	var car: Car = _get_car(scene)
	var run_state: RunState = _get_run_state(scene)
	run_state.reset_for_new_run()
	run_state.start_round(EXTRA_ROUND_TIME)
	car.reset_to_transform(track.get_track_transform(track.get_lap_start_progress(), lateral_offset, CAR_SPAWN_Y_OFFSET))
	await _await_physics_frames(2)

	var max_speed: float = 0.0
	var frame_count: int = int(duration * float(Engine.physics_ticks_per_second))
	for _frame in range(frame_count):
		_apply_drive_input(1.0, 0.0)
		await physics_frame
		max_speed = maxf(max_speed, car.linear_velocity.slide(Vector3.UP).length())

	_clear_drive_input()
	return max_speed


func _progress_delta(start_progress: float, end_progress: float) -> float:
	var delta: float = end_progress - start_progress
	if delta < -0.5:
		delta += 1.0
	elif delta > 0.5:
		delta -= 1.0
	return delta


func _steer_toward(car: Car, target_vector: Vector3) -> float:
	if target_vector.length_squared() < 0.001:
		return 0.0
	var forward: Vector3 = _flat_forward(car)
	var desired: Vector3 = target_vector.normalized()
	var signed_angle: float = atan2(forward.cross(desired).y, forward.dot(desired))
	return clampf(signed_angle / deg_to_rad(24.0), -1.0, 1.0)


func _flat_forward(car: Car) -> Vector3:
	var forward: Vector3 = -car.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return Vector3.FORWARD
	return forward.normalized()


func _apply_drive_input(throttle_strength: float, steer_strength: float) -> void:
	_clear_drive_input()
	if throttle_strength > 0.0:
		Input.action_press("throttle", throttle_strength)
	elif throttle_strength < 0.0:
		Input.action_press("brake", absf(throttle_strength))

	# Match Car's steering_input convention: + = steer_left (turns car left
	# via positive yaw around UP). _steer_toward returns positive when the
	# target is to the car's left, so routing +steer_strength to steer_left
	# makes autopilot steer *toward* the target rather than away from it.
	if steer_strength > 0.0:
		Input.action_press("steer_left", steer_strength)
	elif steer_strength < 0.0:
		Input.action_press("steer_right", absf(steer_strength))


func _clear_drive_input() -> void:
	Input.action_release("throttle")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func _await_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _await_idle_and_physics() -> void:
	await process_frame
	await physics_frame


func _get_track(scene: MainSceneController) -> TestTrack:
	return scene.get_node(^"Track") as TestTrack


func _get_car(scene: MainSceneController) -> Car:
	return scene.get_node(^"Car") as Car


func _get_temporary_grip_modifier(car: Car) -> float:
	if car is PhysicsCar:
		return (car as PhysicsCar)._grip_modifier_multiplier
	if car is SphereCar:
		return (car as SphereCar)._grip_modifier
	return 1.0


func _get_run_state(scene: MainSceneController) -> RunState:
	return scene.get_node(^"RunState") as RunState


func _disable_runtime_feedback(car: Car) -> void:
	if car == null:
		return

	var car_audio: Node = car.get_node_or_null(^"CarAudio")
	if car_audio != null:
		car_audio.queue_free()


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)


func _on_validation_drift_started() -> void:
	_drift_started_count += 1
