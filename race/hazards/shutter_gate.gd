class_name ShutterGate
extends Node3D

const COLLISION_DISABLE_THRESHOLD: float = 0.25
const RETRACT_DISTANCE: float = 1.8
const INDICATOR_BASELINE_ENERGY: float = 0.35
const INDICATOR_PEAK_ENERGY: float = 1.4

@export_range(0.5, 10.0, 0.1) var closed_duration: float = 2.6
@export_range(0.5, 10.0, 0.1) var open_duration: float = 2.0
@export_range(0.05, 1.2, 0.05) var transition_duration: float = 0.35
@export_range(0.0, 20.0, 0.1) var cycle_phase_offset: float = 0.0
@export var base_color: Color = Color(0.18, 0.36, 0.98, 1.0)
@export var accent_color: Color = Color(0.58, 0.86, 1.0, 1.0)
@export var indicator_color: Color = Color(0.58, 0.86, 1.0, 0.55)
@export var preview_valid_color: Color = Color(0.44, 0.68, 1.0, 1.0)
@export var preview_invalid_color: Color = Color(0.98, 0.42, 0.38, 1.0)

@onready var gate_body: AnimatableBody3D = $GateBody
@onready var collision_shape: CollisionShape3D = $GateBody/CollisionShape3D
@onready var base_mesh: MeshInstance3D = $GateBody/BaseMesh
@onready var accent_mesh: MeshInstance3D = $GateBody/AccentMesh
@onready var indicator_mesh: MeshInstance3D = $Indicator/IndicatorMesh

var _preview_mode: bool = false
var _preview_valid: bool = true
var _preview_focused: bool = false
var _base_material: StandardMaterial3D = StandardMaterial3D.new()
var _accent_material: StandardMaterial3D = StandardMaterial3D.new()
var _indicator_material: StandardMaterial3D = StandardMaterial3D.new()
var _cycle_time: float = 0.0
var _closed_fraction: float = 1.0
var _gate_body_rest_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_gate_body_rest_position = gate_body.position
	_configure_materials()
	_apply_visual_state()
	_apply_cycle_pose()


func _physics_process(delta: float) -> void:
	_cycle_time += delta
	_update_cycle_state()
	_apply_cycle_pose()
	_apply_indicator_pulse()


func set_preview_mode(is_preview: bool) -> void:
	_preview_mode = is_preview
	if is_node_ready():
		_apply_visual_state()
		_apply_cycle_pose()


func set_preview_valid(is_valid: bool) -> void:
	_preview_valid = is_valid
	if is_node_ready():
		_apply_visual_state()


func set_preview_focused(is_focused: bool) -> void:
	_preview_focused = is_focused
	if is_node_ready():
		_apply_visual_state()


func _cycle_total_duration() -> float:
	return closed_duration + open_duration + transition_duration * 2.0


func _update_cycle_state() -> void:
	var total: float = _cycle_total_duration()
	if total <= 0.0:
		_closed_fraction = 1.0
		return
	_cycle_time = fposmod(_cycle_time, total)
	var phase: float = fposmod(_cycle_time + cycle_phase_offset, total)
	var opening_start: float = closed_duration
	var open_start: float = opening_start + transition_duration
	var closing_start: float = open_start + open_duration
	if phase < opening_start:
		_closed_fraction = 1.0
	elif phase < open_start:
		_closed_fraction = 1.0 - (phase - opening_start) / transition_duration
	elif phase < closing_start:
		_closed_fraction = 0.0
	else:
		_closed_fraction = (phase - closing_start) / transition_duration


func _apply_cycle_pose() -> void:
	var retract_offset: float = -RETRACT_DISTANCE * (1.0 - _closed_fraction)
	gate_body.position = _gate_body_rest_position + Vector3(0.0, retract_offset, 0.0)
	var should_block: bool = (not _preview_mode) and (_closed_fraction > COLLISION_DISABLE_THRESHOLD)
	collision_shape.set_deferred("disabled", not should_block)


# Indicator glows brighter as the gate is about to slam shut — a ground-level
# telegraph that stays visible even when the gate is fully retracted.
func _apply_indicator_pulse() -> void:
	var energy: float = lerpf(INDICATOR_BASELINE_ENERGY, INDICATOR_PEAK_ENERGY, _closed_fraction)
	_indicator_material.emission_energy_multiplier = energy


func _configure_materials() -> void:
	HazardPreviewHelper.configure_materials(
		base_mesh, accent_mesh, _base_material, _accent_material,
		0.5, 0.08, 0.25, 0.12, 0.7)
	_indicator_material.albedo_color = indicator_color
	_indicator_material.roughness = 0.8
	_indicator_material.emission_enabled = true
	_indicator_material.emission = indicator_color
	_indicator_material.emission_energy_multiplier = INDICATOR_BASELINE_ENERGY
	_indicator_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	indicator_mesh.material_override = _indicator_material


# Collision toggling lives in _apply_cycle_pose so preview and cycle can't fight
# over the disabled flag; this function only writes materials.
func _apply_visual_state() -> void:
	HazardPreviewHelper.apply_visual_state(
		_base_material, _accent_material, base_color, accent_color,
		preview_valid_color, preview_invalid_color, _preview_mode, _preview_valid, _preview_focused,
		func(c: Color) -> Color: return c.lightened(0.18))
