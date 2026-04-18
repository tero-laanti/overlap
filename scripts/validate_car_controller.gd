class_name CarControllerValidator
extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const COIN_SCENE: PackedScene = preload("res://race/coin.tscn")
const BOOST_PAD_SCENE: PackedScene = preload("res://race/boost_pad.tscn")
const SLOW_ZONE_SCENE: PackedScene = preload("res://race/hazards/slow_zone.tscn")
const GRAVEL_SPILL_SCENE: PackedScene = preload("res://race/hazards/gravel_spill.tscn")

const RECTANGLE_LAYOUT_INDEX := 0
const FIGURE_EIGHT_LAYOUT_INDEX := 5
const EXTRA_ROUND_TIME := 120.0
const SURFACE_TEST_SECONDS := 2.0
const AUTOPILOT_TEST_SECONDS := 3.5
const DRIFT_TEST_SECONDS := 2.5
const JUMP_TEST_SECONDS := 4.0
const CAR_SPAWN_Y_OFFSET := 0.37

var _failures: PackedStringArray = []
var _drift_started_count: int = 0


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	await _validate_flat_and_figure_eight()
	await _validate_drift_and_jump()
	await _validate_surface_speeds()
	await _validate_reverse_throttle_release_no_flip()
	await _validate_collision_owner_resolution()
	await _validate_hazard_exit_cleanup_after_owner_cleared()
	await _validate_reset_to_transform_grounded_state()

	_clear_drive_input()
	await _await_idle_and_physics()
	await _await_idle_and_physics()
	quit(1 if not _failures.is_empty() else 0)


func _validate_flat_and_figure_eight() -> void:
	var flat_scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var flat_metrics: Dictionary = await _drive_with_autopilot(flat_scene, AUTOPILOT_TEST_SECONDS)
	print("flat metrics: %s" % flat_metrics)
	if float(flat_metrics.get("progress_delta", 0.0)) <= 0.035:
		_fail("Flat track autopilot did not make enough progress.")
	if int(flat_metrics.get("grounded_frames", 0)) <= int(flat_metrics.get("airborne_frames", 0)):
		_fail("Flat track spent too much time airborne.")
	await _free_scene(flat_scene)

	var figure_eight_scene: MainSceneController = await _spawn_main_scene(FIGURE_EIGHT_LAYOUT_INDEX)
	var figure_eight_metrics: Dictionary = await _drive_with_autopilot(figure_eight_scene, AUTOPILOT_TEST_SECONDS)
	print("figure-eight metrics: %s" % figure_eight_metrics)
	if float(figure_eight_metrics.get("travel_distance", 0.0)) <= 30.0:
		_fail("Figure-eight validation did not cover enough distance.")
	if float(figure_eight_metrics.get("min_height", 0.0)) < -1.0:
		_fail("Figure-eight drive fell too far below the track.")
	await _free_scene(figure_eight_scene)


func _validate_drift_and_jump() -> void:
	var drift_scene: MainSceneController = await _spawn_main_scene(RECTANGLE_LAYOUT_INDEX)
	var drift_metrics: Dictionary = await _drive_for_drift(drift_scene, DRIFT_TEST_SECONDS)
	print("drift metrics: %s" % drift_metrics)
	if int(drift_metrics.get("drift_started_count", 0)) <= 0:
		_fail("Drift test never entered drift.")
	await _free_scene(drift_scene)

	var jump_scene: MainSceneController = await _spawn_main_scene(FIGURE_EIGHT_LAYOUT_INDEX)
	var jump_metrics: Dictionary = await _drive_jump(jump_scene, JUMP_TEST_SECONDS)
	print("jump metrics: %s" % jump_metrics)
	if int(jump_metrics.get("airborne_frames", 0)) <= 4:
		_fail("Jump test never produced a meaningful airborne phase.")
	if not bool(jump_metrics.get("landed", false)):
		_fail("Jump test never recovered to grounded state.")
	if float(jump_metrics.get("air_heading_delta_deg", 0.0)) <= 2.0:
		_fail("Jump air steering did not meaningfully change heading.")
	if float(jump_metrics.get("peak_pitch_deg", 0.0)) <= 0.5:
		_fail("Jump test did not generate a measurable visual pitch transient.")
	if float(jump_metrics.get("post_landing_pitch_deg", INF)) >= 0.5:
		_fail("Visual pitch did not return near neutral after landing.")
	await _free_scene(jump_scene)


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


func _drive_jump(scene: MainSceneController, duration: float) -> Dictionary:
	var car: Car = _get_car(scene)
	var ramp: JumpRamp = scene.get_node(^"Track/JumpRamp") as JumpRamp
	# -ramp.global_basis.z is the ramp's forward (travel direction onto the
	# jump). +ramp.global_basis.z is the opposite: it walks *behind* the ramp,
	# which is where we spawn the car so it drives forward into the ramp.
	var travel_direction: Vector3 = -ramp.global_basis.z
	travel_direction.y = 0.0
	travel_direction = travel_direction.normalized()
	var spawn_transform: Transform3D = Transform3D(
		_basis_from_forward(travel_direction),
		ramp.global_position + ramp.global_basis.z * (ramp.length * 1.6) + Vector3.UP * CAR_SPAWN_Y_OFFSET
	)
	car.reset_to_transform(spawn_transform)
	await _await_physics_frames(2)

	var frame_count: int = int(duration * float(Engine.physics_ticks_per_second))
	var airborne_frames: int = 0
	var landed: bool = false
	var was_airborne: bool = false
	var air_heading_start: Vector3 = Vector3.ZERO
	var air_heading_end: Vector3 = Vector3.ZERO
	var peak_pitch_deg: float = 0.0

	for _frame in range(frame_count):
		var steer: float = 0.0
		if was_airborne:
			steer = 1.0
		elif frame_count > 0 and _frame > int(frame_count * 0.35):
			steer = 0.5
		_apply_drive_input(1.0, steer)
		await physics_frame
		if car._visual_pose != null:
			peak_pitch_deg = maxf(peak_pitch_deg, rad_to_deg(absf(car._visual_pose._visual_pitch_angle)))
		if not car.is_grounded:
			airborne_frames += 1
			if not was_airborne:
				was_airborne = true
				air_heading_start = _flat_forward(car)
			air_heading_end = _flat_forward(car)
		elif was_airborne:
			landed = true
			break

	var post_landing_pitch_deg: float = 0.0
	if landed and car._visual_pose != null:
		_apply_drive_input(0.0, 0.0)
		await _await_physics_frames(int(float(Engine.physics_ticks_per_second) * 1.2))
		post_landing_pitch_deg = rad_to_deg(absf(car._visual_pose._visual_pitch_angle))

	_clear_drive_input()
	return {
		"airborne_frames": airborne_frames,
		"landed": landed,
		"air_heading_delta_deg": rad_to_deg(air_heading_start.angle_to(air_heading_end)) if was_airborne else 0.0,
		"peak_pitch_deg": peak_pitch_deg,
		"post_landing_pitch_deg": post_landing_pitch_deg,
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


func _basis_from_forward(forward: Vector3) -> Basis:
	var safe_forward: Vector3 = forward.normalized() if forward.length_squared() >= 0.001 else Vector3.FORWARD
	var right: Vector3 = safe_forward.cross(Vector3.UP).normalized()
	var corrected_forward: Vector3 = Vector3.UP.cross(right).normalized()
	return Basis(right, Vector3.UP, -corrected_forward)


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
