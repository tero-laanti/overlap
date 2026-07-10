class_name BankMedals
extends RefCounted
## Medal logic for Bank, split out to keep the autoload lean. Medals are
## free recognition badges: derived from a route's PB vs its authored
## par — never stored, never bought, no economy effect. Statics operate
## on the Bank autoload passed in.


static func find_route(bank: Node, route_id: String) -> Resource:
	for route in bank.authored_routes():
		if route.id == route_id:
			return route
	return null


static func tier(bank: Node, route_id: String) -> String:
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
