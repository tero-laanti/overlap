class_name Coin
extends Area3D

const RUN_STATE_GROUP := &"run_state"
const LAP_TRACKER_GROUP := &"lap_tracker"

signal collected(base_value: int, rewarded_value: int)

@export var value: int = 5
@export var run_state_path: NodePath
@export var lap_tracker_path: NodePath
@export var respawn_on_lap: bool = true
@export var spin_speed: float = 2.4
@export var bob_height: float = 0.12
@export var bob_speed: float = 2.6

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var visual: MeshInstance3D = $Visual

var _run_state: RunState = null
var _lap_tracker: LapTracker = null
var _is_collected: bool = false
var _base_visual_position: Vector3 = Vector3.ZERO
var _bob_phase: float = 0.0


func _ready() -> void:
	_run_state = _resolve_run_state()
	_lap_tracker = _resolve_lap_tracker()
	_base_visual_position = visual.position
	_bob_phase = float(get_instance_id() % 1024) * 0.013

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not _run_state:
		push_warning("Coin could not find the run state.")
	elif not _run_state.round_started.is_connected(_on_round_started):
		_run_state.round_started.connect(_on_round_started)
	if respawn_on_lap:
		if not _lap_tracker:
			push_warning("Coin could not find the lap tracker for respawn.")
		elif not _lap_tracker.lap_completed.is_connected(_on_lap_completed):
			_lap_tracker.lap_completed.connect(_on_lap_completed)

	_set_collected(false)


func _process(delta: float) -> void:
	if _is_collected:
		return

	visual.rotate_y(spin_speed * delta)
	var bob_offset: float = sin(Time.get_ticks_msec() / 1000.0 * bob_speed + _bob_phase) * bob_height
	visual.position = _base_visual_position + Vector3.UP * bob_offset


func _on_body_entered(body: Node) -> void:
	if _is_collected:
		return
	if CarBodyResolver.resolve(body) == null:
		return
	if _run_state and not _run_state.is_round_active:
		return

	var rewarded_value: int = value
	if _run_state:
		rewarded_value = _run_state.add_pickup_currency(value)

	collected.emit(value, rewarded_value)
	_set_collected(true)


func _on_lap_completed(_completed_laps: int) -> void:
	if not respawn_on_lap or not _is_collected:
		return
	if _run_state and not _run_state.is_round_active:
		return

	_set_collected(false)


func _on_round_started(_round_number: int) -> void:
	_set_collected(false)


func _set_collected(is_collected: bool) -> void:
	_is_collected = is_collected
	visual.visible = not is_collected
	visual.position = _base_visual_position
	set_deferred("monitoring", not is_collected)
	set_deferred("monitorable", not is_collected)
	collision_shape.set_deferred("disabled", is_collected)


func _resolve_run_state() -> RunState:
	if not run_state_path.is_empty():
		return get_node_or_null(run_state_path) as RunState
	return get_tree().get_first_node_in_group(RUN_STATE_GROUP) as RunState


func _resolve_lap_tracker() -> LapTracker:
	if not lap_tracker_path.is_empty():
		return get_node_or_null(lap_tracker_path) as LapTracker
	return get_tree().get_first_node_in_group(LAP_TRACKER_GROUP) as LapTracker
