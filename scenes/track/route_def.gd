class_name RouteDef
extends Resource
## One authored route: a canonical ordered edge-id sequence from the
## start line back to itself. Routes are authored, never enumerated —
## un-authored circuits are simply not laps. Payout is authored per lap
## and should be income/s-normalized against par_time so no route
## strictly dominates.

@export var id := ""
@export var display_name := "Route"
@export var edges := PackedStringArray()
@export var par_time := 10.0
@export var payout_per_lap := 10.0
