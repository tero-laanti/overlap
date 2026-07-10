class_name RouteDef
extends Resource
## One authored route: a canonical ordered edge-id sequence from the
## start line back to itself. Routes are authored, never enumerated —
## un-authored circuits are simply not laps. Payout is authored per lap
## and should be income/s-normalized against par_time so no route
## strictly dominates.

@export var id := ""
@export var display_name := "Route"
## The island this route lives on: the crossing-line id of the start
## line its laps open and close at (archipelago, MAP_DESIGN_V3 §3).
@export var start_line := "start"
@export var edges := PackedStringArray()
## Maxed-car autopilot benchmark lap (user://calibrate.flag run) — the
## medal yardstick only. Payouts are authored separately; par never
## prices income.
@export var par_time := 10.0
@export var payout_per_lap := 10.0
## Knowledge routes: never hinted in the log, only counted, until driven.
@export var secret := false
## One-line clue shown in the route log while the route is only hinted.
@export var clue := ""
## Livery of this route's ghost fleet — each route reads as its own
## squad on shared asphalt (zone-themed; cyan is the hub family).
@export var ghost_color := Color(0.35, 0.8, 1.0)
## Gates that must all be owned before this route is drivable; owning
## them promotes the route from unknown to hinted in the log.
@export var required_gates := PackedStringArray()
