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
	check(defs.has("quarry") and defs.has("linneas-study"), "sample buildings load")
	if not defs.has("quarry"):
		return
	var quarry: Dictionary = defs["quarry"]
	var l1_cost := TownCore.next_level_cost(quarry, 0)
	check_eq(float(l1_cost.get("gold", 0)), 50.0, "quarry L1 costs 50 gold")
	check(TownCore.next_level_cost(quarry, 3).is_empty(), "maxed building has no next cost")


func test_tick_produces() -> void:
	var defs := DataLoader.load_domain("buildings")
	var town := _empty_town()
	check(TownCore.tick(town, defs).is_empty(), "empty town produces nothing")
	town = TownCore.set_building(town, "quarry", 1)
	town = TownCore.set_building(town, "linneas-study", 2)
	var produced := TownCore.tick(town, defs)
	check_eq(float(produced.get("stone", 0)), 2.0, "quarry L1 produces 2 stone/day")
	check_eq(float(produced.get("knowledge", 0)), 2.0, "study L2 produces 2 knowledge/day")


func test_tick_bad_building_is_loud_but_safe() -> void:
	var defs := DataLoader.load_domain("buildings")
	var town := TownCore.set_building(_empty_town(), "no-such-building", 1)
	town = TownCore.set_building(town, "quarry", 99)  # invalid level
	var produced := TownCore.tick(town, defs)  # push_errors fire (visible), result safe
	check(produced.is_empty(), "unknown building / bad level produce nothing")
