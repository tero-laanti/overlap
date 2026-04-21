class_name CarOptions
extends Object

## Static catalog of car visual variants. Indices are stable so
## `GameSession.selected_car_index` round-trips across scene reloads.
##
## Handles the runtime colormap hue-shift and material override so option
## `.tres` files only store a float and the mesh materials get a tinted
## albedo texture at spawn time.

const OPTION_PATHS: Array[String] = [
	"res://car/options/option_sedan_sunset.tres",
	"res://car/options/option_sedan_ocean.tres",
	"res://car/options/option_sedan_pine.tres",
	"res://car/options/option_kart.tres",
]
const COLORMAP_PATH := "res://car/assets/kenney_car_kit/Textures/colormap.png"

static var _options_cache: Array[CarOption] = []
static var _colormap_cache: Dictionary = {}


static func get_options() -> Array[CarOption]:
	if not _options_cache.is_empty():
		return _options_cache

	for option_path in OPTION_PATHS:
		if not ResourceLoader.exists(option_path):
			push_warning("CarOptions could not find %s." % option_path)
			continue
		var option: CarOption = load(option_path) as CarOption
		if option == null:
			push_warning("CarOptions failed to load %s as CarOption." % option_path)
			continue
		_options_cache.append(option)
	return _options_cache


static func get_option(index: int) -> CarOption:
	var options: Array[CarOption] = get_options()
	if options.is_empty():
		return null
	var clamped_index: int = clampi(index, 0, options.size() - 1)
	return options[clamped_index]


static func clamp_index(index: int) -> int:
	var options: Array[CarOption] = get_options()
	if options.is_empty():
		return 0
	return clampi(index, 0, options.size() - 1)


## Returns a palette texture hue-shifted by `hue_shift` turns. Cached per
## shift value so multiple cars with the same shift share one texture.
## Returns null if the base colormap can't be loaded or decompressed.
static func get_colormap_texture(hue_shift: float) -> Texture2D:
	var key: float = fposmod(hue_shift, 1.0)
	if _colormap_cache.has(key):
		return _colormap_cache[key]

	var base_texture: Texture2D = load(COLORMAP_PATH) as Texture2D
	if base_texture == null:
		push_warning("CarOptions could not load colormap at %s." % COLORMAP_PATH)
		return null

	if is_zero_approx(key):
		_colormap_cache[key] = base_texture
		return base_texture

	var source_image: Image = base_texture.get_image()
	if source_image == null:
		push_warning("CarOptions could not read pixels from colormap.")
		return null

	var working_image: Image = source_image.duplicate() as Image
	if working_image.is_compressed():
		# Imported textures usually arrive as BPTC/ETC2; decompress so
		# get_pixel/set_pixel work. Prototype cost is a one-time unpack at
		# startup, not per frame.
		working_image.decompress()

	_hue_shift_image(working_image, key)
	var shifted_texture: ImageTexture = ImageTexture.create_from_image(working_image)
	_colormap_cache[key] = shifted_texture
	return shifted_texture


## Walks every MeshInstance3D under `body` and forces its albedo texture to
## `texture` via a per-surface override material. Leaves the GLB-authored
## material's other properties (metallic, roughness, culling) intact.
static func apply_colormap_override(body: Node3D, texture: Texture2D) -> void:
	if body == null or texture == null:
		return

	for mesh_instance in _iter_mesh_instances(body):
		if mesh_instance.mesh == null:
			continue
		var surface_count: int = mesh_instance.mesh.get_surface_count()
		for surface_index in surface_count:
			var source_material: Material = null
			if surface_index < mesh_instance.get_surface_override_material_count():
				source_material = mesh_instance.get_surface_override_material(surface_index)
			if source_material == null:
				source_material = mesh_instance.mesh.surface_get_material(surface_index)

			var override_material: StandardMaterial3D = _build_tint_material(source_material, texture)
			mesh_instance.set_surface_override_material(surface_index, override_material)


static func _build_tint_material(source: Material, texture: Texture2D) -> StandardMaterial3D:
	var override: StandardMaterial3D = null
	if source is StandardMaterial3D:
		override = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	if override == null:
		override = StandardMaterial3D.new()
	override.albedo_texture = texture
	return override


static func _hue_shift_image(img: Image, shift_turns: float) -> void:
	var width: int = img.get_width()
	var height: int = img.get_height()
	for y in height:
		for x in width:
			var color: Color = img.get_pixel(x, y)
			color.h = fposmod(color.h + shift_turns, 1.0)
			img.set_pixel(x, y, color)


static func _iter_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			meshes.append(node as MeshInstance3D)
		for child in node.get_children():
			stack.append(child)
	return meshes
