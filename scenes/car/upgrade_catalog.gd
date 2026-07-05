class_name UpgradeCatalog
extends Resource
## Flat catalog of all purchasable upgrades. Single authored instance at
## data/upgrades/catalog.tres; Bank loads it.

const UpgradeDefScript = preload("res://scenes/car/upgrade_def.gd")

@export var upgrades: Array[UpgradeDefScript] = []


func find(id: String) -> UpgradeDefScript:
	for def in upgrades:
		if def.id == id:
			return def
	return null
