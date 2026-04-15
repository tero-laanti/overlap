class_name DriftFeedback
extends Node3D

## Rear emitter offsets match the current 2x0.5x4 grey-box car body in main.tscn.
const LEFT_REAR_SMOKE_OFFSET := Vector3(-0.75, -0.18, 1.35)
const RIGHT_REAR_SMOKE_OFFSET := Vector3(0.75, -0.18, 1.35)
const SMOKE_AMOUNT := 18
const SMOKE_LIFETIME := 0.45
const SMOKE_SPREAD := 30.0
const SMOKE_DIRECTION := Vector3(0.0, 0.35, 1.0)
const SMOKE_GRAVITY := Vector3(0.0, 1.5, 0.0)
const SMOKE_INITIAL_VELOCITY_MIN := 1.5
const SMOKE_INITIAL_VELOCITY_MAX := 3.5
const SMOKE_SCALE_MIN := 0.7
const SMOKE_SCALE_MAX := 1.2
const SMOKE_DAMPING_MIN := 2.0
const SMOKE_DAMPING_MAX := 4.0
const SMOKE_SPIN_MIN := -120.0
const SMOKE_SPIN_MAX := 120.0
const SMOKE_VISIBILITY_AABB := AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 4.0, 8.0))
const SMOKE_QUAD_SIZE := Vector2(0.75, 0.75)
const SMOKE_COLOR := Color(0.88, 0.88, 0.88, 0.45)

var car: Car = null
var _emitters: Array[CPUParticles3D] = []


func _ready() -> void:
	if car != null:
		bind_car(car)


func bind_car(car_owner: Car) -> void:
	if car != null and car != car_owner:
		_disconnect_car_signals()

	car = car_owner
	if car == null or not is_node_ready():
		return

	if _emitters.is_empty():
		_emitters = [
			_create_smoke_emitter("LeftRearSmoke", LEFT_REAR_SMOKE_OFFSET),
			_create_smoke_emitter("RightRearSmoke", RIGHT_REAR_SMOKE_OFFSET),
		]

	if not car.drift_started.is_connected(_on_car_drift_started):
		car.drift_started.connect(_on_car_drift_started)
	if not car.drift_ended.is_connected(_on_car_drift_ended):
		car.drift_ended.connect(_on_car_drift_ended)

	_set_emitters_active(car.is_drifting)


func _create_smoke_emitter(emitter_name: String, offset: Vector3) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.name = emitter_name
	emitter.position = offset
	emitter.amount = SMOKE_AMOUNT
	emitter.lifetime = SMOKE_LIFETIME
	emitter.local_coords = false
	emitter.one_shot = false
	emitter.emitting = false
	emitter.spread = SMOKE_SPREAD
	emitter.direction = SMOKE_DIRECTION
	emitter.gravity = SMOKE_GRAVITY
	emitter.initial_velocity_min = SMOKE_INITIAL_VELOCITY_MIN
	emitter.initial_velocity_max = SMOKE_INITIAL_VELOCITY_MAX
	emitter.scale_amount_min = SMOKE_SCALE_MIN
	emitter.scale_amount_max = SMOKE_SCALE_MAX
	emitter.damping_min = SMOKE_DAMPING_MIN
	emitter.damping_max = SMOKE_DAMPING_MAX
	emitter.angular_velocity_min = SMOKE_SPIN_MIN
	emitter.angular_velocity_max = SMOKE_SPIN_MAX
	emitter.visibility_aabb = SMOKE_VISIBILITY_AABB
	emitter.mesh = _create_smoke_mesh()
	add_child(emitter)
	return emitter


func _create_smoke_mesh() -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = SMOKE_COLOR
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh := QuadMesh.new()
	mesh.size = SMOKE_QUAD_SIZE
	mesh.material = material
	return mesh


func _set_emitters_active(is_active: bool) -> void:
	for emitter: CPUParticles3D in _emitters:
		emitter.emitting = is_active


func _disconnect_car_signals() -> void:
	if not is_instance_valid(car):
		return

	if car.drift_started.is_connected(_on_car_drift_started):
		car.drift_started.disconnect(_on_car_drift_started)
	if car.drift_ended.is_connected(_on_car_drift_ended):
		car.drift_ended.disconnect(_on_car_drift_ended)


func _on_car_drift_started() -> void:
	if is_instance_valid(car):
		_set_emitters_active(true)


func _on_car_drift_ended() -> void:
	if is_instance_valid(car):
		_set_emitters_active(false)
