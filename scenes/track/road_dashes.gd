@tool
extends Node2D
## Painted centerline dashes along a road. The parent RoadSegment feeds
## the baked centerline into `points` on every bake; drawing happens in
## the segment's local space so the node needs no transform of its own.

const DASH_LENGTH := 42.0
const GAP_LENGTH := 58.0
const HALF_WIDTH := 4.0

var points := PackedVector2Array():
	set(value):
		points = value
		queue_redraw()
var dash_color := Color(0.92, 0.92, 0.9, 0.28):
	set(value):
		dash_color = value
		queue_redraw()


func _draw() -> void:
	if points.size() < 2:
		return
	var cycle := DASH_LENGTH + GAP_LENGTH
	var travelled := 0.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length < 0.001:
			continue
		var direction := (b - a) / length
		var normal := Vector2(-direction.y, direction.x) * HALF_WIDTH
		# Every dash cycle that intersects [travelled, travelled+length].
		var first := floorf(travelled / cycle) * cycle
		var start := first
		while start < travelled + length:
			var from := maxf(start, travelled) - travelled
			var to := minf(start + DASH_LENGTH, travelled + length) - travelled
			# Sliver dashes at segment ends triangulate degenerate quads.
			if to - from > 2.0:
				var p0 := a + direction * from
				var p1 := a + direction * to
				draw_colored_polygon(PackedVector2Array([
					p0 - normal, p1 - normal, p1 + normal, p0 + normal,
				]), dash_color)
			start += cycle
		travelled += length
