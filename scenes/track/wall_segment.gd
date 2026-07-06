@tool
class_name WallSegment
extends Path2D
## A solid wall (cliff face) baked from a Curve2D centerline — the same
## offset pipeline as RoadSegment, but the ribbon is a StaticBody2D the
## car really collides with. Risk is for YOUR lap only: ghosts have no
## collision, so recorded lines replay through untouched.

const RoadSegmentScript = preload("res://scenes/track/road_segment.gd")

@export var half_thickness := 16.0:
	set(value):
		half_thickness = value
		_bake()
@export var color := Color(0.45, 0.44, 0.48):
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
	var centerline := curve.tessellate(RoadSegmentScript.TESSELLATE_STAGES,
			RoadSegmentScript.TESSELLATE_TOLERANCE_DEGREES)
	var polygons := Geometry2D.offset_polyline(centerline, half_thickness,
			Geometry2D.JOIN_ROUND, Geometry2D.END_SQUARE)
	if polygons.is_empty():
		return
	var face: Polygon2D = $Face
	var hitbox: CollisionPolygon2D = $Body/Hitbox
	face.polygon = RoadSegmentScript._largest(polygons)
	face.color = color
	hitbox.polygon = face.polygon
