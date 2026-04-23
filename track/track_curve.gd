@tool
class_name TrackCurve
extends RefCounted

const DEFAULT_SAMPLE_SPACING: float = 2.5
const MIN_SAMPLE_SPACING: float = 0.25
const DEDUPE_DISTANCE_SQUARED: float = 0.0001
const MITER_DENOMINATOR_EPSILON: float = 0.15
const MITER_LENGTH_LIMIT: float = 4.0
const MIN_HERMITE_SUBDIVISIONS: int = 4
const HERMITE_SUBDIVISION_SPACING_RATIO: float = 0.5


static func build_smoothed_path(
	control_points: Array[Vector3],
	closed: bool = false,
	sample_spacing: float = DEFAULT_SAMPLE_SPACING,
	start_tangent: Vector3 = Vector3.ZERO,
	end_tangent: Vector3 = Vector3.ZERO
) -> Array[Vector3]:
	var points: Array[Vector3] = _dedupe_points(control_points, closed)
	if points.size() < 2:
		return points

	var hermite_points: Array[Vector3] = _sample_hermite_polyline(
		points,
		closed,
		sample_spacing,
		start_tangent,
		end_tangent
	)
	return _resample_polyline(hermite_points, closed, sample_spacing)


static func build_offset_path(
	path_points: Array[Vector3],
	offset: float,
	closed: bool = false,
	start_tangent: Vector3 = Vector3.ZERO,
	end_tangent: Vector3 = Vector3.ZERO
) -> Array[Vector3]:
	var points: Array[Vector3] = _dedupe_points(path_points, closed)
	if points.size() < 2:
		return points

	var offset_points: Array[Vector3] = []
	offset_points.resize(points.size())
	var last_index: int = points.size() - 1

	for point_index in range(points.size()):
		var previous_index: int = (point_index - 1 + points.size()) % points.size()
		var next_index: int = (point_index + 1) % points.size()
		var has_previous: bool = closed or point_index > 0
		var has_next: bool = closed or point_index < last_index
		var previous_normal: Vector3 = Vector3.ZERO
		var next_normal: Vector3 = Vector3.ZERO

		if has_previous:
			previous_normal = _get_right_normal(points[previous_index], points[point_index])
		if has_next:
			next_normal = _get_right_normal(points[point_index], points[next_index])

		var offset_direction: Vector3 = Vector3.ZERO
		var offset_scale: float = offset

		if not has_previous:
			offset_direction = _get_right_normal_from_tangent(start_tangent)
			if offset_direction.length_squared() < DEDUPE_DISTANCE_SQUARED:
				offset_direction = next_normal
		elif not has_next:
			offset_direction = _get_right_normal_from_tangent(end_tangent)
			if offset_direction.length_squared() < DEDUPE_DISTANCE_SQUARED:
				offset_direction = previous_normal
		elif previous_normal.length_squared() < DEDUPE_DISTANCE_SQUARED:
			offset_direction = next_normal
		elif next_normal.length_squared() < DEDUPE_DISTANCE_SQUARED:
			offset_direction = previous_normal
		else:
			var miter: Vector3 = previous_normal + next_normal
			if miter.length_squared() < DEDUPE_DISTANCE_SQUARED:
				offset_direction = next_normal
			else:
				offset_direction = miter.normalized()
				var denominator: float = offset_direction.dot(next_normal)
				if absf(denominator) < MITER_DENOMINATOR_EPSILON:
					offset_direction = next_normal
				else:
					offset_scale = offset / denominator
					var max_miter_length: float = absf(offset) * MITER_LENGTH_LIMIT
					offset_scale = clampf(offset_scale, -max_miter_length, max_miter_length)

		if offset_direction.length_squared() < DEDUPE_DISTANCE_SQUARED:
			offset_direction = Vector3(0.0, 0.0, 1.0)

		offset_points[point_index] = points[point_index] + offset_direction.normalized() * offset_scale

	return offset_points


static func _sample_hermite_polyline(
	points: Array[Vector3],
	closed: bool,
	sample_spacing: float,
	start_tangent: Vector3,
	end_tangent: Vector3
) -> Array[Vector3]:
	if points.size() < 2:
		return points

	var tangents: Array[Vector3] = _build_hermite_tangents(points, closed, start_tangent, end_tangent)
	var sampled_points: Array[Vector3] = [points[0]]
	var point_count: int = points.size()
	var segment_count: int = point_count if closed else point_count - 1
	var subdivision_spacing: float = maxf(sample_spacing * HERMITE_SUBDIVISION_SPACING_RATIO, MIN_SAMPLE_SPACING)

	for point_index in range(segment_count):
		var next_index: int = (point_index + 1) % point_count
		var from_point: Vector3 = points[point_index]
		var to_point: Vector3 = points[next_index]
		var subdivisions: int = maxi(
			MIN_HERMITE_SUBDIVISIONS,
			int(ceili(from_point.distance_to(to_point) / subdivision_spacing))
		)
		for subdivision_index in range(1, subdivisions + 1):
			var t: float = float(subdivision_index) / float(subdivisions)
			sampled_points.append(
				_evaluate_hermite(
					from_point,
					to_point,
					tangents[point_index],
					tangents[next_index],
					t
				)
			)

	return _dedupe_points(sampled_points, closed)


static func _build_hermite_tangents(
	points: Array[Vector3],
	closed: bool,
	start_tangent: Vector3,
	end_tangent: Vector3
) -> Array[Vector3]:
	var tangents: Array[Vector3] = []
	tangents.resize(points.size())
	var last_index: int = points.size() - 1

	for point_index in range(points.size()):
		if closed:
			var previous_index: int = (point_index - 1 + points.size()) % points.size()
			var next_index: int = (point_index + 1) % points.size()
			tangents[point_index] = (points[next_index] - points[previous_index]) * 0.5
			continue

		if point_index == 0:
			var start_direction: Vector3 = _resolve_endpoint_direction(start_tangent, points[1] - points[0])
			tangents[point_index] = start_direction * points[0].distance_to(points[1])
		elif point_index == last_index:
			var end_direction: Vector3 = _resolve_endpoint_direction(end_tangent, points[last_index] - points[last_index - 1])
			tangents[point_index] = end_direction * points[last_index].distance_to(points[last_index - 1])
		else:
			tangents[point_index] = (points[point_index + 1] - points[point_index - 1]) * 0.5

	return tangents


static func _evaluate_hermite(
	from_point: Vector3,
	to_point: Vector3,
	from_tangent: Vector3,
	to_tangent: Vector3,
	t: float
) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	var h00: float = 2.0 * t3 - 3.0 * t2 + 1.0
	var h10: float = t3 - 2.0 * t2 + t
	var h01: float = -2.0 * t3 + 3.0 * t2
	var h11: float = t3 - t2
	return from_point * h00 + from_tangent * h10 + to_point * h01 + to_tangent * h11


static func _resolve_endpoint_direction(preferred_tangent: Vector3, fallback_tangent: Vector3) -> Vector3:
	var tangent: Vector3 = preferred_tangent
	if tangent.length_squared() < DEDUPE_DISTANCE_SQUARED:
		tangent = fallback_tangent
	tangent.y = 0.0
	if tangent.length_squared() < DEDUPE_DISTANCE_SQUARED:
		return Vector3.RIGHT
	return tangent.normalized()


static func _resample_polyline(
	points: Array[Vector3],
	closed: bool,
	sample_spacing: float
) -> Array[Vector3]:
	if points.size() < 2:
		return points

	var safe_spacing: float = maxf(sample_spacing, MIN_SAMPLE_SPACING)
	var sampled_points: Array[Vector3] = [points[0]]
	var remaining_distance: float = safe_spacing
	var point_count: int = points.size()
	var segment_count: int = point_count if closed else point_count - 1

	for segment_index in range(segment_count):
		var next_index: int = (segment_index + 1) % point_count
		var from_point: Vector3 = points[segment_index]
		var to_point: Vector3 = points[next_index]
		var segment_vector: Vector3 = to_point - from_point
		var segment_length: float = segment_vector.length()
		if segment_length <= 0.0001:
			continue

		var distance_along_segment: float = remaining_distance
		while distance_along_segment < segment_length:
			sampled_points.append(from_point.lerp(to_point, distance_along_segment / segment_length))
			distance_along_segment += safe_spacing
		remaining_distance = distance_along_segment - segment_length

	if not closed and sampled_points[-1].distance_squared_to(points[-1]) > DEDUPE_DISTANCE_SQUARED:
		sampled_points.append(points[-1])

	return _dedupe_points(sampled_points, closed)


static func _get_right_normal(from_point: Vector3, to_point: Vector3) -> Vector3:
	var direction: Vector3 = to_point - from_point
	return _get_right_normal_from_tangent(direction)


static func _get_right_normal_from_tangent(tangent: Vector3) -> Vector3:
	var direction: Vector3 = tangent
	direction.y = 0.0
	if direction.length_squared() < DEDUPE_DISTANCE_SQUARED:
		return Vector3.ZERO
	direction = direction.normalized()
	return Vector3(-direction.z, 0.0, direction.x)


static func _dedupe_points(points: Array[Vector3], closed: bool) -> Array[Vector3]:
	var deduped_points: Array[Vector3] = []
	for point in points:
		if deduped_points.is_empty():
			deduped_points.append(point)
			continue
		if deduped_points[-1].distance_squared_to(point) <= DEDUPE_DISTANCE_SQUARED:
			continue
		deduped_points.append(point)

	if closed and deduped_points.size() > 1:
		if deduped_points[-1].distance_squared_to(deduped_points[0]) <= DEDUPE_DISTANCE_SQUARED:
			deduped_points.remove_at(deduped_points.size() - 1)

	return deduped_points
