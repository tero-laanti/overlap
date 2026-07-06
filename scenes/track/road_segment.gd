@tool
class_name RoadSegment
extends Path2D
## One road segment. The Curve2D centerline is the single source of
## truth: the drivable surface polygon and the grass-detection hitbox
## (an Area2D on the road_surface physics layer) are baked from it by
## inflating the tessellated centerline with offset_polyline. Square end
## caps overhang junction mouths so touching segments seal without gaps,
## and identical flat colors hide the seams — no polygon unions needed.
## A second, wider bake is the border layer: drawn at z_index -1 so every
## border sits below EVERY surface (two-layer overdraw — junction
## overlaps never stripe). With `rubble` on, the border strip doubles as
## a near-stop off-road hitbox (physics layer 4) instead of grass.

## Curvature-adaptive tessellation bounds (Curve2D.tessellate defaults).
const TESSELLATE_STAGES := 5
const TESSELLATE_TOLERANCE_DEGREES := 4.0

@export var half_width := 150.0:
	set(value):
		half_width = value
		_bake()
@export var color := Color(0.25, 0.25, 0.27):
	set(value):
		color = value
		_bake()
## Extra reach of the border strip beyond the surface edge (0 = none).
@export var border_width := 26.0:
	set(value):
		border_width = value
		_bake()
@export var border_color := Color(0.55, 0.56, 0.6):
	set(value):
		border_color = value
		_bake()
## Rubble shoulders: leaving the surface onto the border strip is a
## near-stop (car reads physics layer 4) instead of ordinary grass.
@export var rubble := false:
	set(value):
		rubble = value
		_bake()


func _ready() -> void:
	_bake()
	if curve != null and not curve.changed.is_connected(_bake):
		curve.changed.connect(_bake)


func _bake() -> void:
	if not is_node_ready() or curve == null or curve.point_count < 2:
		return
	var centerline := curve.tessellate(TESSELLATE_STAGES, TESSELLATE_TOLERANCE_DEGREES)
	var polygons := Geometry2D.offset_polyline(centerline, half_width,
			Geometry2D.JOIN_ROUND, Geometry2D.END_SQUARE)
	if polygons.is_empty():
		return
	var surface: Polygon2D = $Surface
	var hitbox: CollisionPolygon2D = $SurfaceArea/Hitbox
	surface.polygon = _largest(polygons)
	surface.color = color
	hitbox.polygon = surface.polygon
	_bake_border(centerline)


func _bake_border(centerline: PackedVector2Array) -> void:
	var border: Polygon2D = $Border
	var rubble_hitbox: CollisionPolygon2D = $RubbleArea/Hitbox
	border.visible = border_width > 0.0
	if border_width <= 0.0:
		rubble_hitbox.disabled = true
		return
	var polygons := Geometry2D.offset_polyline(centerline,
			half_width + border_width,
			Geometry2D.JOIN_ROUND, Geometry2D.END_SQUARE)
	if polygons.is_empty():
		return
	border.polygon = _largest(polygons)
	border.color = border_color
	rubble_hitbox.polygon = border.polygon if rubble else PackedVector2Array()
	rubble_hitbox.disabled = not rubble


## offset_polyline can return several polygons on degenerate input; the
## drivable surface is always the largest one.
static func _largest(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	var best: PackedVector2Array = polygons[0]
	var best_area := 0.0
	for polygon in polygons:
		var area := _polygon_area(polygon)
		if area > best_area:
			best_area = area
			best = polygon
	return best


static func _polygon_area(polygon: PackedVector2Array) -> float:
	var doubled := 0.0
	for i in polygon.size():
		var j := (i + 1) % polygon.size()
		doubled += polygon[i].cross(polygon[j])
	return absf(doubled) * 0.5
