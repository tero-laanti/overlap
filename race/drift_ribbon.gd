class_name DriftRibbon
extends Area3D

const RUN_STATE_GROUP := &"run_state"
const LAP_TRACKER_GROUP := &"lap_tracker"

const BASELINE_ACCENT_EMISSION := 0.72
const FLASH_DURATION := 0.6
const FLASH_PEAK_MULTIPLIER := 4.5

@export var reward_boost_speed: float = 6.5
@export var stability_grip_bonus: float = 1.15
@export var bonus_duration: float = 0.35
@export var base_color: Color = Color(0.16, 0.36, 0.52, 1.0)
@export var accent_color: Color = Color(0.56, 0.95, 1.0, 1.0)
@export var preview_valid_color: Color = Color(0.42, 0.78, 0.98, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.44, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _run_state: RunState = null
var _lap_tracker: LapTracker = null
var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _active_cars: Dictionary[int, Car] = {}
var _triggered_body_ids: Dictionary[int, bool] = {}
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()
var _flash_time_remaining: float = 0.0


func _ready() -> void:
	_run_state = get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState
	_lap_tracker = get_tree().get_first_node_in_group(LAP_TRACKER_GROUP) as LapTracker

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if _run_state and not _run_state.round_started.is_connected(_on_round_started):
		_run_state.round_started.connect(_on_round_started)
	if _lap_tracker and not _lap_tracker.lap_completed.is_connected(_on_lap_completed):
		_lap_tracker.lap_completed.connect(_on_lap_completed)

	_configure_materials()
	_apply_visual_state()


func _physics_process(_delta: float) -> void:
	if _preview_mode or _active_cars.is_empty():
		return
	if _run_state and not _run_state.is_round_active:
		return

	var stale_body_ids: Array[int] = []
	for body_id in _active_cars.keys():
		var car: Car = _active_cars[body_id]
		if not is_instance_valid(car):
			stale_body_ids.append(body_id)
			continue
		if _triggered_body_ids.has(body_id):
			continue
		if not car.is_drifting:
			continue

		_triggered_body_ids[body_id] = true
		car.apply_forward_boost(reward_boost_speed)
		car.apply_grip_bonus(stability_grip_bonus, bonus_duration)
		_trigger_flash()

	for body_id in stale_body_ids:
		_active_cars.erase(body_id)
		_triggered_body_ids.erase(body_id)


func _process(delta: float) -> void:
	if _flash_time_remaining <= 0.0:
		return
	_flash_time_remaining = maxf(_flash_time_remaining - delta, 0.0)
	_apply_flash_emission()


func _trigger_flash() -> void:
	_flash_time_remaining = FLASH_DURATION
	_apply_flash_emission()


func _apply_flash_emission() -> void:
	if _accent_material == null:
		return
	var flash_t: float = _flash_time_remaining / FLASH_DURATION
	var multiplier: float = lerpf(1.0, FLASH_PEAK_MULTIPLIER, flash_t)
	_accent_material.emission_energy_multiplier = BASELINE_ACCENT_EMISSION * multiplier


func set_preview_mode(is_preview: bool) -> void:
	if is_preview:
		_active_cars.clear()
		_triggered_body_ids.clear()
	_preview_mode = is_preview
	if is_node_ready():
		_apply_visual_state()


func set_preview_valid(is_valid: bool) -> void:
	_preview_valid = is_valid
	if is_node_ready():
		_apply_visual_state()


func set_preview_focused(is_focused: bool) -> void:
	_preview_focused = is_focused
	if is_node_ready():
		_apply_visual_state()


func _on_body_entered(body: Node) -> void:
	if _preview_mode or not (body is Car):
		return
	if _run_state and not _run_state.is_round_active:
		return
	_active_cars[body.get_instance_id()] = body as Car


func _on_body_exited(body: Node) -> void:
	_active_cars.erase(body.get_instance_id())


func _on_round_started(_round_number: int) -> void:
	_triggered_body_ids.clear()


func _on_lap_completed(_completed_laps: int) -> void:
	_triggered_body_ids.clear()


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.35, 0.0, 0.18, 0.02, BASELINE_ACCENT_EMISSION)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.12))
	HazardPreviewHelper.apply_collision_state_area(self, collision_shape, _preview_mode)
