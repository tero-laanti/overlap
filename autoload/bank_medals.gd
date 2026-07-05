class_name BankMedals
extends RefCounted
## Mastery-medal logic for Bank, split out to keep the autoload lean.
## Medals are derived from a route's PB vs its authored par — never
## stored — and only count once that route's mastery timing has been
## bought. Statics operate on the Bank autoload passed in; Bank keeps
## the public API and owns save/signal side effects.


static func find_route(bank: Node, route_id: String) -> Resource:
	for route in bank.authored_routes():
		if route.id == route_id:
			return route
	return null


static func tier(bank: Node, route_id: String) -> String:
	if route_id not in bank.medal_unlocked_routes:
		return ""
	var pb: float = bank.route_pb(route_id)
	var route := find_route(bank, route_id)
	if pb <= 0.0 or route == null or route.par_time <= 0.0:
		return ""
	if pb <= route.par_time:
		return "gold"
	if pb <= route.par_time * bank.ECONOMY.medal_silver_factor:
		return "silver"
	if pb <= route.par_time * bank.ECONOMY.medal_bronze_factor:
		return "bronze"
	return ""


static func multiplier(bank: Node, route_id: String) -> float:
	match tier(bank, route_id):
		"gold":
			return bank.ECONOMY.medal_gold_multiplier
		"silver":
			return bank.ECONOMY.medal_silver_multiplier
		"bronze":
			return bank.ECONOMY.medal_bronze_multiplier
	return 1.0


static func unlock_cost(bank: Node, route_id: String) -> float:
	var route := find_route(bank, route_id)
	return route.medal_unlock_cost if route else INF


## Mutates currency and the unlocked list only; the caller (Bank) saves
## and emits.
static func try_buy_unlock(bank: Node, route_id: String) -> bool:
	if route_id in bank.medal_unlocked_routes:
		return false
	if route_id not in bank.discovered_routes:
		return false
	var cost := unlock_cost(bank, route_id)
	if bank.currency < cost:
		return false
	bank.currency -= cost
	bank.medal_unlocked_routes.append(route_id)
	return true
