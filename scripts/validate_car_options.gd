class_name CarOptionsValidator
extends SceneTree

## Smoke test for the car-picker data path: every `CarOption` resolves, its
## body scene instantiates, the hue-shift pipeline produces a non-null
## texture when requested, and `car_picker.tscn` itself can mount under a
## test root without script errors. Narrow by design — gameplay validators
## (`validate_sphere_car.gd`, `validate_physics_car.gd`) cover how the body
## behaves once spawned on a `Car`.

const CAR_PICKER_SCENE: PackedScene = preload("res://ui/car_picker.tscn")
const MAIN_SCENE: PackedScene = preload("res://main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_validation")


func _run_validation() -> void:
	var options: Array[CarOption] = CarOptions.get_options()
	if options.is_empty():
		_fail("CarOptions.get_options() returned empty.")
		_finish()
		return
	print("car options loaded: %d" % options.size())

	for option_index in options.size():
		_check_option(option_index, options[option_index])

	_check_hue_shift_texture()
	await _check_car_picker_scene()
	await _check_car_body_spawn_in_main_scene()

	_finish()


func _check_option(index: int, option: CarOption) -> void:
	if option == null:
		_fail("Option %d is null." % index)
		return
	if option.body_scene == null:
		_fail("Option %d (%s) has null body_scene." % [index, option.display_name])
		return
	var instance: Node = option.body_scene.instantiate()
	if instance == null:
		_fail("Option %d (%s) failed to instantiate body_scene." % [index, option.display_name])
		return
	if not (instance is Node3D):
		_fail("Option %d (%s) body_scene root is not a Node3D." % [index, option.display_name])
		instance.queue_free()
		return
	print("option %d: %s (hue_shift=%.2f)" % [index, option.display_name, option.hue_shift])
	instance.queue_free()


func _check_hue_shift_texture() -> void:
	# Pick a shift value we actually ship so the test mirrors runtime behavior.
	var shifted: Texture2D = CarOptions.get_colormap_texture(0.55)
	if shifted == null:
		_fail("CarOptions.get_colormap_texture(0.55) returned null.")
		return
	print("hue-shifted colormap: %dx%d" % [shifted.get_width(), shifted.get_height()])


func _check_car_picker_scene() -> void:
	var picker: Control = CAR_PICKER_SCENE.instantiate() as Control
	if picker == null:
		_fail("car_picker.tscn did not instantiate as a Control.")
		return
	root.add_child(picker)
	await _await_physics_frames(2)
	var card_row: HBoxContainer = picker.get_node_or_null(^"CenterContainer/VBox/CardRow") as HBoxContainer
	if card_row == null or card_row.get_child_count() == 0:
		_fail("car_picker populated no cards.")
	else:
		print("car picker populated %d cards" % card_row.get_child_count())
	picker.queue_free()
	await _await_physics_frames(2)


func _check_car_body_spawn_in_main_scene() -> void:
	var game_session: Node = root.get_node_or_null(^"GameSession")
	if game_session == null:
		_fail("GameSession autoload missing.")
		return

	for option_index in CarOptions.get_options().size():
		game_session.set("selected_car_index", option_index)
		var scene: Node3D = MAIN_SCENE.instantiate() as Node3D
		root.add_child(scene)
		await _await_physics_frames(2)

		var car: Car = scene.get_node_or_null(^"Car") as Car
		if car == null:
			_fail("main.tscn missing Car node at option %d." % option_index)
			scene.queue_free()
			await _await_physics_frames(1)
			continue

		var body: Node3D = car.get_node_or_null(^"VisualRoot/Body") as Node3D
		if body == null:
			_fail("Car spawned no Body for option %d." % option_index)
		else:
			print("option %d body spawned: %s (children=%d)" % [option_index, body.name, body.get_child_count()])

		scene.queue_free()
		await _await_physics_frames(1)


func _finish() -> void:
	quit(1 if not _failures.is_empty() else 0)


func _await_physics_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame


func _fail(message: String) -> void:
	push_error(message)
	_failures.append(message)
