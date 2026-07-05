class_name UpgradeCatalog
extends Resource
## Flat catalog of all purchasable upgrades. Single authored instance at
## data/upgrades/catalog.tres; Bank loads it.

@export var upgrades: Array[UpgradeDef] = []


func find(id: String) -> UpgradeDef:
	for def in upgrades:
		if def.id == id:
			return def
	return null
