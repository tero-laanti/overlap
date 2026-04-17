class_name CoinGate
extends Area3D

const RUN_STATE_GROUP := &"run_state"
const LAP_TRACKER_GROUP := &"lap_tracker"

@export var reward_value: int = 8
@export var center_tolerance: float = 0.7
@export var base_color: Color = Color(0.46, 0.28, 0.08, 1.0)
@export var accent_color: Color = Color(1.0, 0.84, 0.26, 1.0)
@export var preview_valid_color: Color = Color(0.96, 0.82, 0.34, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.44, 0.38, 1.0)

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var base_mesh: MeshInstance3D = $BaseMesh
@onready var accent_mesh: MeshInstance3D = $AccentMesh

var _run_state: RunState = null
var _lap_tracker: LapTracker = null
var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _triggered_body_ids: Dictionary[int, bool] = {}
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()


func _ready() -> void:
	_run_state = get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState
	_lap_tracker = get_tree().get_first_node_in_group(LAP_TRACKER_GROUP) as LapTracker

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if _run_state and not _run_state.round_started.is_connected(_on_round_started):
		_run_state.round_started.connect(_on_round_started)
	if _lap_tracker and not _lap_tracker.lap_completed.is_connected(_on_lap_completed):
		_lap_tracker.lap_completed.connect(_on_lap_completed)

	_configure_materials()
	_apply_visual_state()


func set_preview_mode(is_preview: bool) -> void:
	if is_preview:
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

	var body_id: int = body.get_instance_id()
	if _triggered_body_ids.has(body_id):
		return

	var local_position: Vector3 = to_local((body as Car).global_position)
	if absf(local_position.x) > center_tolerance:
		return

	_triggered_body_ids[body_id] = true
	if _run_state:
		_run_state.add_pickup_currency(reward_value)


func _on_round_started(_round_number: int) -> void:
	_triggered_body_ids.clear()


func _on_lap_completed(_completed_laps: int) -> void:
	_triggered_body_ids.clear()


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.45, 0.08, 0.18, 0.04, 0.8)


func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.18))
	HazardPreviewHelper.apply_collision_state_area(self, collision_shape, _preview_mode)
