class_name TrackMutationResult
extends RefCounted

## Return value from `TrackMutator.mutate_layout`. `layout` is always the
## layout the caller should install: the mutated copy when `changed` is
## true, otherwise the input layout unchanged. The original_centerline /
## world_center fields are only meaningful when `changed` is true and
## exist to drive the pit-stop telegraph.

var layout: TrackLayout = null
var changed: bool = false
var world_center: Vector3 = Vector3.ZERO
var display_name: String = ""
var original_centerline: Array[Vector3] = []
