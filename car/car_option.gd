class_name CarOption
extends Resource

## A single entry in the car picker roster. `body_scene` is the Kenney GLB,
## `body_transform` is the in-place orientation/scale the body gets under
## `VisualRoot/Body` (the two concrete controllers used to author it directly
## in their `.tscn` — now it's data so each option can tune it), and
## `hue_shift` runtime-shifts the shared colormap texture so the same GLB can
## ship in multiple colors without extra PNGs.

@export var display_name: String = "Coupe"
@export var description: String = ""
@export var body_scene: PackedScene
## Per-model intrinsic transform (scale, axis flip, small Y tweak). The
## concrete controller layers its own ground offset (sphere proxy vs box
## proxy sit at different Y) on top of `origin.y` at spawn time.
@export var body_transform: Transform3D = Transform3D(
	Basis.IDENTITY.scaled(Vector3(-2.0, 2.0, -2.0)),
	Vector3.ZERO
)
## 0.0 = use the colormap as-is. >0 = hue-shift the full palette by this
## many turns (0.5 = 180°) at load time. Runtime-generated, cached in
## `CarOptions`.
@export_range(0.0, 1.0, 0.01) var hue_shift: float = 0.0
## Picker-only zoom factor. Kenney sedans at `scale=2` overshoot the small
## preview viewport; this shrinks the visible body in the picker without
## touching the in-game body_transform.
@export_range(0.2, 2.0, 0.05) var preview_scale: float = 1.0
## Picks the physics controller used in game. null = fall through to the
## track's `preferred_vehicle`, then to `main.tscn`'s default. Setting this
## makes the car choice authoritative — overrides any track-level
## `preferred_vehicle`.
@export var controller_override: PackedScene
## Short controller tag shown on the picker card (e.g., "Sphere",
## "Normal"). Purely descriptive; the actual controller comes from
## `controller_override`.
@export var controller_label: String = ""
