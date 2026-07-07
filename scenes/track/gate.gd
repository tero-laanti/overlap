class_name Gate
extends StaticBody2D
## A purchasable barrier on a branch mouth. Purchased state lives in
## Bank; the gate reads it on ready and opens itself on the purchase
## signal. Collision is toggled deferred — never mid-physics-flush.

@export var gate_id := ""

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	add_to_group("gate")
	if Bank.is_gate_purchased(gate_id):
		_open()
	Events.gate_purchased.connect(func(id: String) -> void:
		if id == gate_id:
			_open())


func _open() -> void:
	_shape.set_deferred("disabled", true)
	visible = false
