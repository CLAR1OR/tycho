extends "res://tests/test_suite.gd"
## Tests MarketCore (src/town/market_core.gd) — the exchange-rate reader and the
## caravan-deal rotation — plus a content lint on data/town/caravan-deals.json
## (civilian resources only: the Market never trades Resonance, IC-14).


func test_caps_reads_the_built_levels_rates() -> void:
	var defs := DataLoader.load_domain("buildings")
	var market: Dictionary = defs["market"]
	check(MarketCore.caps(market, 0).is_empty(), "an unbuilt market has no rates")
	var l1 := MarketCore.caps(market, 1)
	check_eq(float(l1["sell_food_rate"]), 1.0, "L1 sells food at 1.0")
	check_eq(int(l1["buy_stone_gold"]), 5, "L1 buys stone at 5 gold")
	check_eq(int(l1["deal_slots"]), 1, "L1 shows one caravan deal")
	var l3 := MarketCore.caps(market, 3)
	check_eq(int(l3["deal_slots"]), 2, "L3 opens the second deal slot")
	check(float(l3["sell_food_rate"]) > float(l1["sell_food_rate"]),
		"levels REPLACE — L3 carries its own better rate")
	check(MarketCore.caps(market, 99).is_empty(), "an out-of-range level has no rates")


func test_deal_rotation_deterministic() -> void:
	var deals := DataLoader.load_caravan_deals()
	check(deals.size() >= 4, "the caravan table carries at least 4 deals (%d)" % deals.size())
	var ids := MarketCore.deal_order(deals)
	check_eq(ids.size(), deals.size(), "deal_order lists every deal once")
	var sorted_copy := ids.duplicate()
	sorted_copy.sort()
	check_eq(ids, sorted_copy, "the rotation order is the sorted ids (deterministic)")
	# Slot 0 rotates day mod n, and the same day always shows the same deal.
	var n := ids.size()
	check_eq(MarketCore.deal_id_for_slot(deals, 3, 0), str(ids[3 % n]), "slot 0 = deals[day mod n]")
	check_eq(MarketCore.deal_id_for_slot(deals, 3 + n, 0), str(ids[3 % n]),
		"the rotation wraps a full cycle later")
	check_eq(MarketCore.deal_id_for_slot(deals, 7, 0), MarketCore.deal_id_for_slot(deals, 7, 0),
		"the same day always offers the same deal (no RNG state)")
	# The L3 second slot is deterministic too and never mirrors slot 0.
	for day in 12:
		var a := MarketCore.deal_id_for_slot(deals, day, 0)
		var b := MarketCore.deal_id_for_slot(deals, day, 1)
		check(not b.is_empty() and b != a, "day %d: the second slot offers a distinct deal" % day)
	check_eq(MarketCore.deal_id_for_slot({}, 5, 0), "", "an empty table offers nothing")
	check_eq(MarketCore.deal_id_for_slot(deals, 5, 2), "", "there is no third slot")


func test_deal_accept_once_per_day() -> void:
	var town := {"id": "home", "buildings": [], "market_deal_done_day": -1}
	check(MarketCore.can_accept_deal(town, 4), "a fresh town can accept today's deal")
	var done := MarketCore.mark_deal_done(town, 4)
	check(not MarketCore.can_accept_deal(done, 4), "one accept per day — day 4 is spent")
	check(MarketCore.can_accept_deal(done, 5), "the next day offers again")
	check_eq(int(town.get("market_deal_done_day", -1)), -1,
		"mark_deal_done returns a new dict, input untouched")
	# defaults-merge safety: a town dict without the key still answers sanely.
	check(MarketCore.can_accept_deal({"id": "old"}, 1), "a pre-market town can accept")


func test_caravan_deals_are_civilian_only() -> void:
	# IC-14: the Market never trades Resonance — lint the data table itself.
	var deals := DataLoader.load_caravan_deals()
	var civilian := ["gold", "stone", "food"]
	for id: String in deals:
		var deal: Dictionary = deals[id]
		check(not str(deal.get("text", "")).is_empty(), "%s carries its pitch line" % id)
		for side in ["give", "get"]:
			for res: String in (deal.get(side, {}) as Dictionary):
				check(res in civilian, "%s.%s trades civilian resources only (%s)" % [id, side, res])
			check(not (deal.get(side, {}) as Dictionary).is_empty(), "%s.%s is non-empty" % [id, side])