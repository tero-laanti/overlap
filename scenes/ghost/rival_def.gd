class_name RivalDef
extends Resource
## One authored rival: a named recording raced head-to-head from each
## lap start. Authored by DevRivalRecord (user://rivalrecord.flag) — a
## base-car autopilot lap slowed by a handicap so a first-session player
## beats it within a few laps. Replay only, no AI (VISION scope fence,
## amended 2026-07-10).

const LapRecordingScript = preload("res://scenes/ghost/lap_recording.gd")

@export var id := ""
@export var display_name := "RIVAL"
## Only laps on this route race (and can beat) the rival.
@export var route_id := "ring"
@export var recording: LapRecordingScript
