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
	# The v2 return keys are STABLE — present (0.0) even with no Market built.
	check(implicit.has("food_sold") and implicit.has("gold_from_sale"),
		"tick always returns the market keys (stable shape)")
	check_eq(float(implicit["food_sold"]), 0.0, "no market → food_sold 0.0")
	check_eq(float(implicit["gold_from_sale"]), 0.0, "no market → gold_from_sale 0.0")


# --- Town economy v2: age-banded levels + Market + Cathedral (town-economy.md) --------

func test_is_level_unlocked_gates() -> void:
	var defs := DataLoader.load_domain("buildings")
	var farm: Dictionary = defs["farm"]
	check(TownCore.is_level_unlocked(farm, 0, []), "an ungated level is always unlocked")
	check(TownCore.is_level_unlocked(farm, 1, []), "farm L2 carries no gate")
	check(not TownCore.is_level_unlocked(farm, 2, []),
		"farm L3 is gated by Three-Field Rotation (unauthored — dormant forward ref)")
	check(TownCore.is_level_unlocked(farm, 2, ["med-three-field-rotation"]),
		"farm L3 unlocks once its tech is researched")
	check(not TownCore.is_level_unlocked(defs["quarry"], 1, []),
		"quarry L2 is gated by The Wheel & Axle")
	# A forward reference to an unauthored tech id never loud-fails — it just stays shut.
	check(not TownCore.is_level_unlocked(defs["library"], 3, []),
		"the Library's University opener waits on ren-printing-press (forward ref)")
	check(not TownCore.is_level_unlocked(farm, 99, []), "an out-of-range level index is locked")


func test_is_level_unlocked_unknown_gate_type_is_locked() -> void:
	# A typo'd gate type must LOCK (loudly) — mirrors is_unlocked's rule.
	var def := {"id": "fixture", "levels": [{"unlocked_by": {"type": "wizard", "id": "x"}}]}
	check(not TownCore.is_level_unlocked(def, 0, ["x"]),
		"unknown gate type locks the level (push_error fires, visible above)")


func test_display_name_rename() -> void:
	var defs := DataLoader.load_domain("buildings")
	var lib: Dictionary = defs["library"]
	check_eq(TownCore.display_name(lib, 0), "Library", "unbuilt library reads Library")
	check_eq(TownCore.display_name(lib, 3), "Library", "L3 library is still the Library")
	check_eq(TownCore.display_name(lib, 4), "University",
		"the built band opener renames it (highest built rename wins)")
	check_eq(TownCore.display_name(defs["farm"], 2), "Farm", "no rename → the def name")


func test_multiplier_folds_into_produced() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Study L1 (1 knowledge) + Library L1 (x1.10 knowledge), starving (no bonus):
	# 1 x 1.10 = 1.1. Gates guard the PURCHASE only — an already-built library ticks.
	var town := TownCore.set_building(_empty_town(), "sophias-study", 1)
	town = TownCore.set_building(town, "library", 1)
	var p: Dictionary = TownCore.tick(town, defs, 0.0)["produced"]
	check(absf(float(p.get("knowledge", 0.0)) - 1.1) < 0.0001,
		"library folds x1.10 into the study's knowledge (got %.3f)" % float(p.get("knowledge", 0.0)))
	# Mill L1 multiplies food AND stone — with neither produced, both are no-ops.
	var lone_mill := TownCore.set_building(_empty_town(), "mill", 1)
	var p2: Dictionary = TownCore.tick(lone_mill, defs, 0.0)["produced"]
	check(not p2.has("food") and not p2.has("stone"),
		"a multiplier on a resource nothing produced is a no-op (stays absent)")
	# Mill + farm, starving: food 3 x 1.10 = 3.3 (food never gets the Well-Fed bonus,
	# and stock 0 + 3.3 food < upkeep 2+2 = 4 → not fed anyway).
	var mf := TownCore.set_building(lone_mill, "farm", 1)
	var r3 := TownCore.tick(mf, defs, 0.0)
	check(absf(float((r3["produced"] as Dictionary).get("food", 0.0)) - 3.3) < 0.0001,
		"mill folds x1.10 into the farm's food (3 -> 3.3)")


func test_market_auto_sell_math() -> void:
	var defs := DataLoader.load_domain("buildings")
	# Empty town + Market L1: built 1 → nominal upkeep 3, buffer 2x3 = 6. Stock 20,
	# nothing produced, consumed 3 → after 17 → surplus 11 → sold 11 @ rate 1.0.
	var town := TownCore.set_building(_empty_town(), "market", 1)
	var r := TownCore.tick(town, defs, 20.0)
	check_eq(float(r["food_sold"]), 11.0, "sells the stock above the 2-day buffer (11)")
	check_eq(float(r["gold_from_sale"]), 11.0, "L1 sell rate 1.0 → 11 gold")
	# L2's better rate (1.5) — same surplus, more gold.
	var t2 := TownCore.set_building(_empty_town(), "market", 2)
	var r2 := TownCore.tick(t2, defs, 20.0)
	check_eq(float(r2["food_sold"]), 11.0, "the surplus is rate-independent")
	check_eq(float(r2["gold_from_sale"]), 16.5, "L2 sell rate 1.5 → 16.5 gold")
	# Short stock: nothing above the buffer → no sale (stable 0.0 keys).
	var short := TownCore.tick(town, defs, 4.0)
	check_eq(float(short["food_sold"]), 0.0, "stock at/below the buffer sells nothing")
	check_eq(float(short["gold_from_sale"]), 0.0, "no surplus → no gold")
	# The buffer is NOMINAL (scale-independent): scale 2 doubles the upkeep eaten but
	# not the stock target. built 1 → upkeep 3x2 = 6 eaten; after = 20-6 = 14; buffer 6
	# → sold 8.
	var scaled := TownCore.tick(town, defs, 20.0, 2.0)
	check_eq(float(scaled["food_sold"]), 8.0, "keep-buffer stays nominal under scale (sold 8)")


func test_capability_value_sums_current_levels() -> void:
	var defs := DataLoader.load_domain("buildings")
	check_eq(TownCore.capability_value(_empty_town(), defs, "shard_value_add"), 0.0,
		"an empty town has no capability value")
	var t1 := TownCore.set_building(_empty_town(), "cathedral", 1)
	check_eq(TownCore.capability_value(t1, defs, "shard_value_add"), 0.0,
		"cathedral stage 1 carries no shard bonus yet")
	var t3 := TownCore.set_building(_empty_town(), "cathedral", 3)
	check_eq(TownCore.capability_value(t3, defs, "shard_value_add"), 1.0,
		"the finished cathedral adds +1 shard value")
