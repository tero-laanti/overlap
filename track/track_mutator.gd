@tool
class_name TrackMutator
extends Resource

const TrackDirectionRef := preload("res://track/track_direction.gd")
const TrackLayoutTileRef := preload("res://track/track_layout_tile.gd")
const DEFAULT_DETOUR_MODULES: Array[TrackTileDefinition] = [
	preload("res://track/tiles/detour_bump_short_1x2.tres"),
	preload("res://track/tiles/detour_bump_long_2x2.tres"),
	preload("res://track/tiles/detour_hairpin_short_1x3.tres"),
	preload("res://track/tiles/detour_hairpin_long_2x3.tres"),
	preload("res://track/tiles/detour_chicane_short_1x3.tres"),
]

## Detour tiles the mutator may splice in. Each must expose opposite
## entry/exit directions so it can drop in for a straight with matching
## base entry/exit directions and footprint.
@export var detour_modules: Array[TrackTileDefinition] = DEFAULT_DETOUR_MODULES

## True when the most recent mutate_layout call replaced a tile. Populated
## synchronously so callers can read it right after mutate_layout returns.
var last_mutation_changed: bool = false
## World-space centroid of the spliced detour's occupied cells. Zero when
## the last call did not change the layout. Used to focus camera on the
## new section in the pit-stop telegraph.
var last_mutation_world_center: Vector3 = Vector3.ZERO
## Display name of the detour tile used in the most recent splice, for UI
## telegraph text. Empty when no mutation occurred.
var last_mutation_display_name: String = ""
## World-space centerline points of the spliced detour tile, ordered entry
## → exit. Used by the reveal overlay to draw a highlight ribbon over the
## new section. Empty when no mutation occurred.
var last_mutation_centerline: Array[Vector3] = []
## World-space centerline points of the straight tile that the detour
## replaced, captured before the splice. Used by the reveal overlay to
## draw a ghost of the old racing line for before/after comparison.
var last_mutation_original_centerline: Array[Vector3] = []


## Returns a duplicated layout with one straight tile replaced by a detour
## module, or the input layout unchanged if no valid splice was possible.
## Skips candidates whose footprint world bounds contain any of
## occupied_world_positions so placed hazards and boost pads are not orphaned.
func mutate_layout(
	source_layout: TrackLayout,
	occupied_world_positions: Array[Vector3]
) -> TrackLayout:
	last_mutation_changed = false
	last_mutation_world_center = Vector3.ZERO
	last_mutation_display_name = ""
	last_mutation_centerline = []
	last_mutation_original_centerline = []

	if source_layout == null:
		return source_layout
	if detour_modules.is_empty():
		push_warning("TrackMutator has no detour modules configured.")
		return source_layout

	var candidates: Array[Dictionary] = _collect_candidates(source_layout, occupied_world_positions)
	if candidates.is_empty():
		return source_layout

	var selected: Dictionary = candidates[randi() % candidates.size()]
	var selected_index: int = selected["tile_index"]
	var selected_detour: TrackTileDefinition = selected["detour_tile"]
	var mutated_layout: TrackLayout = _build_mutated_layout(source_layout, selected_index, selected_detour)

	var validation_issues: PackedStringArray = mutated_layout.get_validation_issues()
	if not validation_issues.is_empty():
		for issue in validation_issues:
			push_warning("TrackMutator rejected splice: %s" % issue)
		return source_layout

	var original_tile: TrackLayoutTile = source_layout.tiles[selected_index]
	last_mutation_changed = true
	last_mutation_display_name = selected_detour.display_name
	last_mutation_world_center = _compute_detour_world_center(
		source_layout.tile_size,
		original_tile,
		selected_detour
	)
	var mutated_detour_tile: TrackLayoutTile = mutated_layout.tiles[selected_index]
	last_mutation_centerline = mutated_detour_tile.get_world_points(mutated_layout.tile_size)
	last_mutation_original_centerline = original_tile.get_world_points(source_layout.tile_size)
	return mutated_layout


func _compute_detour_world_center(
	tile_size: float,
	original_tile: TrackLayoutTile,
	detour_tile: TrackTileDefinition
) -> Vector3:
	var detour_grid_position: Vector2i = _compute_detour_grid_position(original_tile, detour_tile)
	var occupied_cells: Array[Vector2i] = detour_tile.get_occupied_cells(original_tile.rotation_steps)
	if occupied_cells.is_empty():
		return Vector3(detour_grid_position.x * tile_size, 0.0, detour_grid_position.y * tile_size)

	var sum_x: float = 0.0
	var sum_z: float = 0.0
	for local_cell in occupied_cells:
		sum_x += float(detour_grid_position.x + local_cell.x)
		sum_z += float(detour_grid_position.y + local_cell.y)

	var count: float = float(occupied_cells.size())
	return Vector3(sum_x / count * tile_size, 0.0, sum_z / count * tile_size)


func _collect_candidates(
	source_layout: TrackLayout,
	occupied_world_positions: Array[Vector3]
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var tile_size: float = source_layout.tile_size

	for tile_index in range(source_layout.tiles.size()):
		var layout_tile: TrackLayoutTile = source_layout.tiles[tile_index]
		if layout_tile == null or layout_tile.tile == null:
			continue
		if _footprint_contains_any_position(layout_tile, tile_size, occupied_world_positions):
			continue
		for detour_tile in detour_modules:
			if detour_tile == null:
				continue
			if not _matches_detour_sockets(layout_tile, detour_tile):
				continue
			if not _detour_fits(source_layout, tile_index, layout_tile, detour_tile):
				continue
			candidates.append({"tile_index": tile_index, "detour_tile": detour_tile})

	return candidates


## A candidate must be a straight whose base entry/exit directions, footprint,
## and socket cells match the detour's, so the replacement preserves socket
## continuity with neighbors at any shared rotation_steps / reverse_path value.
func _matches_detour_sockets(layout_tile: TrackLayoutTile, detour_tile: TrackTileDefinition) -> bool:
	if layout_tile == null or layout_tile.tile == null:
		return false
	var definition: TrackTileDefinition = layout_tile.tile
	if not TrackDirectionRef.are_opposites(definition.entry_direction, definition.exit_direction):
		return false
	if definition.entry_direction != detour_tile.entry_direction:
		return false
	if definition.exit_direction != detour_tile.exit_direction:
		return false
	if definition.get_sanitized_footprint() != _candidate_footprint_for_detour(detour_tile):
		return false
	return true


## Detours encode the candidate straight's footprint by stacking extra cells
## orthogonal to travel. A 1x2 detour (0,1)→(0,1) replaces a 1x1 straight;
## a 2x2 detour (0,1)→(1,1) replaces a 2x1 straight; in general, the straight
## footprint is the detour footprint collapsed to a single row along travel.
func _candidate_footprint_for_detour(detour_tile: TrackTileDefinition) -> Vector2i:
	var footprint: Vector2i = detour_tile.get_sanitized_footprint()
	return Vector2i(footprint.x, 1)


func _footprint_contains_any_position(
	layout_tile: TrackLayoutTile,
	tile_size: float,
	occupied_world_positions: Array[Vector3]
) -> bool:
	if occupied_world_positions.is_empty() or tile_size <= 0.0:
		return false
	var occupied_cells: Array[Vector2i] = layout_tile.get_occupied_cells()
	for position in occupied_world_positions:
		var cell: Vector2i = Vector2i(roundi(position.x / tile_size), roundi(position.z / tile_size))
		if occupied_cells.has(cell):
			return true
	return false


func _detour_fits(
	source_layout: TrackLayout,
	original_index: int,
	original_tile: TrackLayoutTile,
	detour_tile: TrackTileDefinition
) -> bool:
	var detour_grid_position: Vector2i = _compute_detour_grid_position(original_tile, detour_tile)
	var detour_cells: Array[Vector2i] = _compute_detour_world_cells(detour_grid_position, original_tile, detour_tile)
	var original_cells: Array[Vector2i] = original_tile.get_occupied_cells()

	for world_cell in detour_cells:
		if original_cells.has(world_cell):
			continue
		for other_index in range(source_layout.tiles.size()):
			if other_index == original_index:
				continue
			var other_tile: TrackLayoutTile = source_layout.tiles[other_index]
			if other_tile == null or other_tile.tile == null:
				continue
			if other_tile.get_occupied_cells().has(world_cell):
				return false

	return true


func _compute_detour_grid_position(
	original_tile: TrackLayoutTile,
	detour_tile: TrackTileDefinition
) -> Vector2i:
	var detour_entry_cell: Vector2i = detour_tile.get_entry_cell(
		original_tile.rotation_steps,
		original_tile.reverse_path
	)
	return original_tile.get_entry_grid_position() - detour_entry_cell


func _compute_detour_world_cells(
	detour_grid_position: Vector2i,
	original_tile: TrackLayoutTile,
	detour_tile: TrackTileDefinition
) -> Array[Vector2i]:
	var world_cells: Array[Vector2i] = []
	for local_cell in detour_tile.get_occupied_cells(original_tile.rotation_steps):
		world_cells.append(detour_grid_position + local_cell)
	return world_cells


func _build_mutated_layout(
	source_layout: TrackLayout,
	replace_index: int,
	detour_tile: TrackTileDefinition
) -> TrackLayout:
	var mutated_layout: TrackLayout = TrackLayout.new()
	mutated_layout.display_name = source_layout.display_name
	mutated_layout.tile_size = source_layout.tile_size
	mutated_layout.lap_start_progress = source_layout.lap_start_progress

	var mutated_tiles: Array[TrackLayoutTile] = []
	for tile_index in range(source_layout.tiles.size()):
		var original_tile: TrackLayoutTile = source_layout.tiles[tile_index]
		if tile_index == replace_index:
			mutated_tiles.append(_build_detour_layout_tile(original_tile, detour_tile))
		else:
			mutated_tiles.append(_copy_layout_tile(original_tile))

	mutated_layout.tiles = mutated_tiles
	return mutated_layout


func _build_detour_layout_tile(
	original_tile: TrackLayoutTile,
	detour_tile: TrackTileDefinition
) -> TrackLayoutTile:
	var detour_layout_tile: TrackLayoutTile = TrackLayoutTileRef.new()
	detour_layout_tile.tile = detour_tile
	detour_layout_tile.rotation_steps = original_tile.rotation_steps
	detour_layout_tile.reverse_path = original_tile.reverse_path
	detour_layout_tile.grid_position = _compute_detour_grid_position(original_tile, detour_tile)
	return detour_layout_tile


func _copy_layout_tile(original_tile: TrackLayoutTile) -> TrackLayoutTile:
	var copy: TrackLayoutTile = TrackLayoutTileRef.new()
	if original_tile == null:
		return copy
	copy.tile = original_tile.tile
	copy.grid_position = original_tile.grid_position
	copy.rotation_steps = original_tile.rotation_steps
	copy.reverse_path = original_tile.reverse_path
	return copy
