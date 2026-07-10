class_name ShopPacing
extends RefCounted
## What the GARAGE currently offers — the shop evolves during a run:
## upgrades reveal as total owned levels grow and only the cheapest
## unpurchased gate shows at a time (concertina pacing). Pure reads over
## the Bank autoload passed in; shared by the shop and the HUD's
## next-purchase hint.


static func total_upgrade_levels(bank: Node) -> int:
	var total := 0
	for id: String in bank.upgrade_levels:
		total += bank.upgrade_levels[id]
	return total


static func visible_upgrades(bank: Node) -> Array:
	var visible := []
	var total := total_upgrade_levels(bank)
	for def in bank.CATALOG.upgrades:
		if def.unlock_total_levels <= total:
			visible.append(def)
	return visible


## Gates go on sale only once ghosts exist (the rival ladder is done) —
## during onboarding the island is just the hub.
static func next_gate(bank: Node) -> Resource:
	if bank.ghost_slots < 1:
		return null
	var cheapest: Resource = null
	for gate in bank.unpurchased_gates():
		if cheapest == null or gate.price < cheapest.price:
			cheapest = gate
	return cheapest


## The Jump Kit becomes the ticket to the Port island in V3-2
## (MAP_DESIGN_V3 §2) — parked until that strait exists.
static func jump_kit_offered(_bank: Node) -> bool:
	return false
