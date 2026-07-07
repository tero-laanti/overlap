class_name DevProbeReport
extends RefCounted
## DevProbe's observation helpers, split out to keep the probe scenario
## under the line ceiling. Pure reads and prints — never drives anything.

const CarScript = preload("res://scenes/car/car.gd")


static func dump_route_log(tree: SceneTree) -> void:
	var route_log := tree.root.get_node_or_null("Main/RouteLog")
	if route_log == null:
		return
	for line: String in route_log.entries_text():
		print("[PROBE] routelog | %s" % line)


## Drift trail Line2Ds live as siblings of the car; the count rising in
## corners and falling again proves per-stint spawn + fade-out cleanup.
static func trail_count(car: CarScript) -> int:
	var container := car.get_parent()
	if container == null:
		return 0
	var count := 0
	for child in container.get_children():
		if child is Line2D:
			count += 1
	return count


## Saves one frame and returns the next shot index (unchanged when a
## frame can't be captured, e.g. headless).
static func save_screenshot(viewport: Viewport, dir: String, index: int) -> int:
	if DisplayServer.get_name() == "headless":
		return index
	var image := viewport.get_texture().get_image()
	if image == null:
		return index
	image.save_png("%s/frame_%02d.png" % [dir, index])
	return index + 1
