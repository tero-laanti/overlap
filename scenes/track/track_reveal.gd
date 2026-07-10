extends Node
## Progressive map reveal. Every annex node carries a "zone_<gate_id>"
## group tag; this controller shows a zone fully once its gate is owned,
## shows ONLY its roads as a faint preview while it is the next gate on
## sale, and hides it (visuals and collision) otherwise. Gate bars stay
## visible always — a locked door is a promise, not noise. Secret roads
## (forest) carry no zone tag and keep their own reveal rules.

const RoadSegmentScript = preload("res://scenes/track/road_segment.gd")
const ShopPacingScript = preload("res://scenes/ui/shop_pacing.gd")

const PREVIEW_ALPHA := 0.22

enum Zone { HIDDEN, PREVIEW, OWNED }

@onready var _track: Node2D = get_parent()


func _ready() -> void:
	Events.gate_purchased.connect(func(_id: String) -> void: _sync())
	# Gates go on sale when ghosts unlock — the first preview appears then.
	Events.ghost_hired.connect(func(_count: int) -> void: _sync())
	Events.profile_reset.connect(_sync)
	# Deferred: sibling annexes (wall ribbons, road bakes) build their
	# collision children in their own _ready, which may run after ours.
	_sync.call_deferred()


func _sync() -> void:
	var next: Resource = ShopPacingScript.next_gate(Bank)
	for gate in _track.network.gates:
		var state := Zone.HIDDEN
		if Bank.is_gate_purchased(gate.id):
			state = Zone.OWNED
		elif next != null and next.id == gate.id:
			state = Zone.PREVIEW
		for node in get_tree().get_nodes_in_group("zone_%s" % gate.id):
			_apply(node, state)


## Roads show from PREVIEW up (faint until owned); dressing and their
## collision shapes only exist once the zone is owned.
func _apply(node: Node, state: Zone) -> void:
	var shown := state == Zone.OWNED
	if node is RoadSegmentScript:
		shown = state != Zone.HIDDEN
		node.modulate.a = 1.0 if state == Zone.OWNED else PREVIEW_ALPHA
	if node is CanvasItem:
		node.visible = shown
	for shape in node.find_children("*", "CollisionShape2D", true, false):
		shape.set_deferred("disabled", not shown)
	for poly in node.find_children("*", "CollisionPolygon2D", true, false):
		poly.set_deferred("disabled", not shown)
