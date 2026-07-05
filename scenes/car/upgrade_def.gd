class_name UpgradeDef
extends Resource
## One purchasable car upgrade. Effects are multiplicative on a CarStats
## property (additive bonuses are forbidden — see docs/DESIGN_NOTES.md).
## Authored as .tres files in data/upgrades/.

@export var id := ""
@export var display_name := ""
## CarStats property this upgrade multiplies.
@export var stat := ""
@export var effect_multiplier := 1.05
@export var base_cost := 50.0
@export var cost_growth := 1.15
@export var max_level := 15
## The GARAGE reveals this upgrade once the player owns this many
## upgrade levels in total — the shop evolves during a run.
@export var unlock_total_levels := 0


func cost_at(level: int) -> float:
	return base_cost * pow(cost_growth, level)
