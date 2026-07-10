class_name BankIncome
extends RefCounted
## Income math for Bank, split out to keep the autoload lean. Statics
## operate on the Bank autoload passed in — no state here. Bank keeps
## the public API; payouts and offline grants stay Bank's side effects.

const BankMedalsScript = preload("res://autoload/bank_medals.gd")


## ×2 for every fleet milestone reached (10/25/50 ghosts by default).
static func milestone_multiplier(bank: Node) -> float:
	var m := 1.0
	for count in bank.ECONOMY.milestone_counts:
		if bank.ghost_slots >= count:
			m *= bank.ECONOMY.milestone_multiplier
	return m


static func route_income_per_second(bank: Node, route_id: String) -> float:
	var pb: float = bank.route_pb(route_id)
	if pb <= 0.0 or not bank.is_route_fleet_active(route_id):
		return 0.0
	return bank.ghost_slots * bank.route_payout(route_id) \
			* milestone_multiplier(bank) \
			* BankMedalsScript.multiplier(bank, route_id) / pb


static func income_per_second(bank: Node) -> float:
	var total := 0.0
	for route_id: String in bank.route_records:
		total += route_income_per_second(bank, route_id)
	return total
