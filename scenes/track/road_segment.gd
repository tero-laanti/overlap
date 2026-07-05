@tool
class_name RoadSegment
extends Path2D
## One road segment. The Curve2D centerline is the single source of
## truth: the drivable surface polygon and the grass-detection hitbox
## (an Area2D on the road_surface physics layer) are baked from it by
## inflating the tessellated centerline with offset_polyline. Square end
## caps overhang junction mouths so touching segments seal without gaps,
## and identical flat colors hide the seams — no polygon unions needed.
## Curved petals later just author curvier centerlines.

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
