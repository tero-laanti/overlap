class_name CarBodyResolver
extends RefCounted


static func resolve(body: Node) -> Car:
	if body == null:
		return null
	if body is Car:
		return body as Car
	if body is CarPhysicsProxy:
		return (body as CarPhysicsProxy).car_owner
	return null
