@tool
class_name TrackLayoutTile
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")
const TrackTileDefinitionResource := preload("res://track/track_tile_definition.gd")

@export var tile: TrackTileDefinitionResource = null
@export var grid_position: Vector2i = Vector2i.ZERO
@export_range(0, 7, 1) var rotation_steps: int = 0
@export var reverse_path: bool = false


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
