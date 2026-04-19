class_name CarPhysicsProxy
extends RigidBody3D

var car_owner: Car = null


func bind_car(new_car_owner: Car) -> void:
	car_owner = new_car_owner


func get_car_owner() -> Car:
	return car_owner


func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not body_shape_entered.is_connected(_on_body_shape_entered):
		body_shape_entered.connect(_on_body_shape_entered)


func _exit_tree() -> void:
	car_owner = null


func _on_body_entered(body: Node) -> void:
	if is_instance_valid(car_owner):
		car_owner._relay_proxy_body_entered(body)


func _on_body_exited(body: Node) -> void:
	if is_instance_valid(car_owner):
		car_owner._relay_proxy_body_exited(body)


func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if is_instance_valid(car_owner):
		car_owner._relay_proxy_body_shape_entered(body_rid, body, body_shape_index, local_shape_index)
