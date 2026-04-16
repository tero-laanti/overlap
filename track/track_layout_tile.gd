@tool
class_name TrackLayoutTile
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")
const TrackTileDefinitionResource := preload("res://track/track_tile_definition.gd")

var _tile: TrackTileDefinitionResource = null
var _grid_position: Vector2i = Vector2i.ZERO
var _rotation_steps: int = 0
var _reverse_path: bool = false

@export var tile: TrackTileDefinitionResource:
	get:
		return _tile
	set(value):
		_tile = value
		_refresh_tile_definition_observer()
		emit_changed()
@export var grid_position: Vector2i:
	get:
		return _grid_position
	set(value):
		_grid_position = value
		emit_changed()
@export_range(0, 7, 1) var rotation_steps: int:
	get:
		return _rotation_steps
	set(value):
		_rotation_steps = value
		emit_changed()
@export var reverse_path: bool:
	get:
		return _reverse_path
	set(value):
		_reverse_path = value
		emit_changed()

var _observed_tile_definition: TrackTileDefinitionResource = null


func _init() -> void:
	_refresh_tile_definition_observer()


func get_entry_direction() -> int:
	if tile == null:
		return TrackDirectionRef.Heading.N
	return tile.get_entry_direction(rotation_steps, reverse_path)


func get_exit_direction() -> int:
	if tile == null:
		return TrackDirectionRef.Heading.N
	return tile.get_exit_direction(rotation_steps, reverse_path)


func get_entry_cell() -> Vector2i:
	if tile == null:
		return Vector2i.ZERO
	return tile.get_entry_cell(rotation_steps, reverse_path)


func get_exit_cell() -> Vector2i:
	if tile == null:
		return Vector2i.ZERO
	return tile.get_exit_cell(rotation_steps, reverse_path)


func get_entry_grid_position() -> Vector2i:
	return grid_position + get_entry_cell()


func get_exit_grid_position() -> Vector2i:
	return grid_position + get_exit_cell()


func get_occupied_cells() -> Array[Vector2i]:
	var occupied_cells: Array[Vector2i] = []
	if tile == null:
		return occupied_cells

	for cell in tile.get_occupied_cells(rotation_steps):
		occupied_cells.append(grid_position + cell)

	return occupied_cells


func get_configuration_issues() -> PackedStringArray:
	if tile == null:
		return PackedStringArray()
	return tile.get_configuration_issues(rotation_steps)


func get_display_name() -> String:
	if tile == null or tile.display_name.is_empty():
		return "Tile"
	return tile.display_name


func get_world_points(tile_size: float) -> Array[Vector3]:
	if tile == null:
		return []
	return tile.get_world_points(tile_size, grid_position, rotation_steps, reverse_path)


func _refresh_tile_definition_observer() -> void:
	if _observed_tile_definition != null and _observed_tile_definition.changed.is_connected(_on_tile_definition_changed):
		_observed_tile_definition.changed.disconnect(_on_tile_definition_changed)

	_observed_tile_definition = tile
	if _observed_tile_definition != null and not _observed_tile_definition.changed.is_connected(_on_tile_definition_changed):
		_observed_tile_definition.changed.connect(_on_tile_definition_changed)


func _on_tile_definition_changed() -> void:
	emit_changed()
