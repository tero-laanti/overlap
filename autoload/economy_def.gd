class_name EconomyDef
extends Resource
## Global economy tuning. Single authored instance at data/economy.tres.
## Numbers come from the pacing simulation — see docs/DESIGN_NOTES.md
## "Tuned economy v1".

@export var ghost_base_cost := 25.0
@export var ghost_cost_growth := 1.30
## Player's own completed laps pay payout × this (active play always beats
## watching — the anti-"optimal play is not playing" guard).
@export var active_lap_multiplier := 3.0
## Offline income is capped so long absences help without trivializing the loop.
@export var offline_cap_seconds := 8.0 * 60.0 * 60.0
## Fleet sizes that each multiply all income by milestone_multiplier.
@export var milestone_counts: Array[int] = [10, 25, 50]
@export var milestone_multiplier := 2.0
## Mastery medals: a route's PB vs its authored par_time. Gold at or
## under par; silver/bronze within these factors of par. Each tier
## permanently multiplies that route's fleet income.
@export var medal_silver_factor := 1.1
@export var medal_bronze_factor := 1.25
@export var medal_gold_multiplier := 1.5
@export var medal_silver_multiplier := 1.25
@export var medal_bronze_multiplier := 1.1
