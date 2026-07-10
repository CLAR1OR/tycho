extends "res://tests/test_suite.gd"
## Tests TownCore (src/town/town_core.gd) — the pure day tick + building helpers —
## against the REAL data/buildings/ definitions (doubles as a content lint).


func _empty_town() -> Dictionary:
	return {"id": "home", "name": "Home", "age": 1, "buildings": [], "map_pos": null}


func test_building_level_and_set() -> void:
	var town := _empty_town()
	check_eq(TownCore.building_level(town, "quarry"), 0, "unbuilt building is level 0")
	town = TownCore.set_building(town, "quarry", 1)
	check_eq(TownCore.building_level(town, "quarry"), 1, "set_building adds at level 1")
	town = TownCore.set_building(town, "quarry", 2)
	check_eq(TownCore.building_level(town, "quarry"), 2, "set_building bumps in place")
	check_eq((town["buildings"] as Array).size(), 1, "no duplicate entries on upgrade")


func test_set_building_is_pure() -> void:
	var town := _empty_town()
	var before := town.duplicate(true)
	TownCore.set_building(town, "quarry", 1)
	check_eq((town["buildings"] as Array).size(), (before["buildings"] as Array).size(),
		"set_building returns a new dict, input untouched")


func test_next_level_cost() -> void:
	var defs := DataLoader.load_domain("buildings")
	check(defs.has("quarry") and defs.has("sophias-study"), "sample buildings load")
	if not defs.has("quarry"):
		return
	var quarry: Dictionary = defs["quarry"]
	var l1_cost := TownCore.next_level_cost(quarry, 0)
	check_eq(float(l1_cost.get("gold", 0)), 50.0, "quarry L1 costs 50 gold")
	check(TownCore.next_level_cost(quarry, 3).is_empty(), "maxed building has no next cost")


func test_tick_produces() -> void:
	var defs := DataLoader.load_domain("buildings")
	var town := _empty_town()
	# food_stock 0 → not well-fed → no bonus, so the raw production numbers hold.
	check((TownCore.tick(town, defs, 0.0)["produced"] as Dictionary).is_empty(),
		"empty town produces nothing")
	town = TownCore.set_building(town, "quarry", 1)
	town = TownCore.set_building(town, "sophias-study", 2)
	var produced: Dictionary = TownCore.tick(town, defs, 0.0)["produced"]
	check_eq(float(produced.get("stone", 0)), 2.0, "quarry L1 produces 2 stone/day")
	check_eq(float(produced.get("knowledge", 0)), 2.0, "study L2 produces 2 knowledge/day")


func test_tick_bad_building_is_loud_but_safe() -> void:
	var defs := DataLoader.load_domain("buildings")
	var town := TownCore.set_building(_empty_town(), "no-such-building", 1)
	town = TownCore.set_building(town, "quarry", 99)  # invalid level
	var result := TownCore.tick(town, defs, 0.0)  # push_errors fire (visible), result safe
	check((result["produced"] as Dictionary).is_empty(),
		"unknown building / bad level produce nothing")


# --- Food upkeep (design/food-upkeep.md) --------------------------------------------

func test_upkeep_scales_with_building_count() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Empty town: base upkeep 2, no food → not well-fed, but eats what it has (0).
	var r0 := TownCore.tick(_empty_town(), defs, 0.0)
	check_eq(float(r0["food_consumed"]), 0.0, "empty town with no food consumes nothing (never negative)")
	check(not bool(r0["well_fed"]), "empty starving town is not well-fed")
	# One building, plenty of food: upkeep = 2 base + 1 = 3.
	var town := TownCore.set_building(_empty_town(), "sophias-study", 1)
	var r1 := TownCore.tick(town, defs, 50.0)
	check_eq(float(r1["food_consumed"]), 3.0, "1 building → upkeep 3 (2 base + 1)")
	# Two buildings: upkeep = 2 base + 2 = 4.
	town = TownCore.set_building(town, "quarry", 1)
	var r2 := TownCore.tick(town, defs, 50.0)
	check_eq(float(r2["food_consumed"]), 4.0, "2 buildings → upkeep 4 (2 base + 2)")


func test_well_fed_coverage_boundary() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Base upkeep 2 for an empty town. Exactly 2 food available = well-fed (>=).
	var at := TownCore.tick(_empty_town(), defs, 2.0)
	check(bool(at["well_fed"]), "exactly enough food (2 == upkeep 2) is well-fed")
	check_eq(float(at["food_consumed"]), 2.0, "at the boundary the town eats the full upkeep")
	# One under the line is not well-fed.
	var under := TownCore.tick(_empty_town(), defs, 1.99)
	check(not bool(under["well_fed"]), "just short of upkeep is not well-fed")
	check_eq(float(under["food_consumed"]), 1.99, "short town eats all it has, no more")


func test_farm_harvest_counts_before_the_town_eats() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Farm L1 makes 3 food. With 0 stock, available = 0 + 3 = 3 ≥ upkeep 3 (2+1) → fed.
	var town := TownCore.set_building(_empty_town(), "farm", 1)
	var r := TownCore.tick(town, defs, 0.0)
	check(bool(r["well_fed"]), "the harvest arrives before upkeep — a lone farm feeds the town")
	check_eq(float((r["produced"] as Dictionary).get("food", 0)), 3.0, "farm L1 produces 3 food")


func test_well_fed_bonus_applies_to_others_never_food() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Farm L1 (3 food) + study L2 (2 knowledge) + quarry L1 (2 stone), fat food stock.
	var town := TownCore.set_building(_empty_town(), "farm", 1)
	town = TownCore.set_building(town, "sophias-study", 2)
	town = TownCore.set_building(town, "quarry", 1)
	var r := TownCore.tick(town, defs, 100.0)
	check(bool(r["well_fed"]), "stocked town is well-fed")
	var p: Dictionary = r["produced"]
	check_eq(float(p.get("knowledge", 0)), 2.5, "well-fed +25% lifts knowledge 2 → 2.5")
	check_eq(float(p.get("stone", 0)), 2.5, "well-fed +25% lifts stone 2 → 2.5")
	check_eq(float(p.get("food", 0)), 3.0, "food itself is never boosted (stays 3)")


func test_short_town_gets_no_penalty() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Study L2 (2 knowledge), no food at all: not well-fed → raw numbers, no penalty.
	var town := TownCore.set_building(_empty_town(), "sophias-study", 2)
	var r := TownCore.tick(town, defs, 0.0)
	check(not bool(r["well_fed"]), "no food → not well-fed")
	check_eq(float((r["produced"] as Dictionary).get("knowledge", 0)), 2.0,
		"short on food = no bonus, but never a penalty (knowledge stays 2)")
	check_eq(float(r["food_consumed"]), 0.0, "no food to eat → consumes 0, no negative")


# --- Room-scaled tick (human decision 2026-07-10) -------------------------------------

func test_run_tick_scale_math() -> void:
	check_eq(TownCore.run_tick_scale(0), 0.0, "0 rooms cleared → zero tick")
	check_eq(TownCore.run_tick_scale(10), 1.0, "10 rooms = one nominal day (PER_ROOM_TICK 0.1)")
	check_eq(TownCore.run_tick_scale(25), 2.5, "25 rooms = 2.5 nominal days")
	check_eq(TownCore.run_tick_scale(-3), 0.0, "negative input clamps to zero")


func test_tick_scale_multiplies_production_and_upkeep() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Quarry L1 (2 stone) + study L2 (2 knowledge), fat granary, scale 2.0:
	# raw production x2, upkeep (2 base + 2 buildings) x2 = 8, fed → +25% on non-food.
	var town := TownCore.set_building(_empty_town(), "quarry", 1)
	town = TownCore.set_building(town, "sophias-study", 2)
	var r := TownCore.tick(town, defs, 100.0, 2.0)
	check_eq(float(r["food_consumed"]), 8.0, "upkeep scales: (2+2) x 2.0 = 8")
	check(bool(r["well_fed"]), "granary covers the scaled upkeep")
	check_eq(float((r["produced"] as Dictionary).get("stone", 0)), 5.0,
		"stone 2 x scale 2.0 x well-fed 1.25 = 5")
	check_eq(float((r["produced"] as Dictionary).get("knowledge", 0)), 5.0,
		"knowledge 2 x scale 2.0 x well-fed 1.25 = 5")
	# Fractional scale (a partial run) produces fractional amounts — Ledger holds floats.
	var frac := TownCore.tick(town, defs, 0.0, 0.5)
	check_eq(float((frac["produced"] as Dictionary).get("stone", 0)), 1.0,
		"stone 2 x scale 0.5 = 1 (no bonus, starving)")
	check_eq(float(frac["food_consumed"]), 0.0, "no food → still consumes nothing under scale")


func test_well_fed_boundary_under_scale() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Empty town at scale 0.5: upkeep 2 x 0.5 = 1. Exactly 1 food = well-fed (judged
	# on the SCALED numbers); one hair under is not.
	var at := TownCore.tick(_empty_town(), defs, 1.0, 0.5)
	check(bool(at["well_fed"]), "exactly the scaled upkeep (1.0) is well-fed")
	check_eq(float(at["food_consumed"]), 1.0, "eats the scaled upkeep at the boundary")
	var under := TownCore.tick(_empty_town(), defs, 0.99, 0.5)
	check(not bool(under["well_fed"]), "just short of the scaled upkeep is not well-fed")


func test_tick_default_scale_is_one_nominal_day() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Backward compat: omitting scale == passing 1.0 — every per-day caller
	# (HUD projections) keeps meaning one nominal day.
	var town := TownCore.set_building(_empty_town(), "farm", 1)
	town = TownCore.set_building(town, "quarry", 1)
	var implicit := TownCore.tick(town, defs, 20.0)
	var explicit := TownCore.tick(town, defs, 20.0, 1.0)
	check_eq(implicit, explicit, "tick(...) == tick(..., 1.0) — default scale is nominal")
