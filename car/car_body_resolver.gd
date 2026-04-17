class_name CarBodyResolver
extends RefCounted


static func resolve(body: Node) -> Car:
	if body == null:
		return null
	if body is Car:
		return body as Car
	if body.has_method("get_car_owner"):
		return body.call("get_car_owner") as Car
	return null
