class_name LapCounterHUD
extends CanvasLayer

@export var tracker_path: NodePath
@export var label_path: NodePath

var _tracker: LapTracker = null
var _label: Label = null


func _ready() -> void:
	_tracker = get_node_or_null(tracker_path) as LapTracker
	_label = get_node_or_null(label_path) as Label

	if not _label:
		push_warning("LapCounterHUD is missing its label node.")
		return

	if not _tracker:
		push_warning("LapCounterHUD could not find the lap tracker.")
		_label.text = "Lap --"
		return

	_tracker.lap_changed.connect(_on_lap_changed)
	_update_label(_tracker.current_lap)


func _on_lap_changed(current_lap: int) -> void:
	_update_label(current_lap)


func _update_label(current_lap: int) -> void:
	_label.text = "Lap %d" % current_lap
