class_name CarPhysicsProxy
extends RigidBody3D

var car_owner: Car = null


func bind_car(owner: Car) -> void:
	car_owner = owner


func get_car_owner() -> Car:
	return car_owner


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)
	if not body_shape_exited.is_connected(_on_body_shape_exited):
		body_shape_exited.connect(_on_body_shape_exited)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if car_owner != null:
		car_owner._integrate_proxy_forces(state)


func _on_body_entered(body: Node) -> void:
	if car_owner != null:
		car_owner._relay_proxy_body_entered(body)


func _on_body_exited(body: Node) -> void:
	if car_owner != null:
		car_owner._relay_proxy_body_exited(body)


func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if car_owner != null:
		car_owner._relay_proxy_body_shape_entered(body_rid, body, body_shape_index, local_shape_index)


func _on_body_shape_exited(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if car_owner != null:
		car_owner._relay_proxy_body_shape_exited(body_rid, body, body_shape_index, local_shape_index)
