extends "res://tests/test_suite.gd"
## Tests BuildPanelCore (src/town/build_panel_core.gd) — the town-building screens' pure
## helpers: the ledger entries, the yield lines, the build action, the carry-resource set, and
## the deterministic survey order. Costs/levels come from the real building data
## (farm 40 gold / 250+8 stone / 525+18 stone — L2/L3 gold rebalanced 2026-07-10;
## yields 3/5/8 food; walls = a capability effect).


func test_entry_rows_farm() -> void:
	var defs := DataLoader.load_domain("buildings")
	var rows := BuildPanelCore.entry_rows(defs["farm"], 1)  # L1 built
	check_eq(rows.size(), 3, "farm has three level entries")
	check_eq(int(rows[0]["level"]), 1, "first entry is level 1")
	check_eq(str(rows[0]["state"]), "built", "L1 is built at current_level 1")
	check_eq(str(rows[1]["state"]), "next", "L2 is the next to buy")
	check_eq(str(rows[2]["state"]), "beyond", "L3 is beyond next")
	check_eq(int((rows[1]["cost"] as Dictionary)["gold"]), 250, "L2 costs 250 gold")
	check_eq(int((rows[1]["cost"] as Dictionary)["stone"]), 8, "L2 costs 8 stone")


func test_yield_line_produce_and_capability() -> void:
	var defs := DataLoader.load_domain("buildings")
	var y1 := BuildPanelCore.yield_line((defs["farm"]["levels"][0] as Dictionary)["effects"])
	check_eq(str(y1["text"]), "3 food a day", "farm L1 yields 3 food a day")
	check_eq(str(y1["resource"]), "food", "farm yield is in the food colour")
	var y3 := BuildPanelCore.yield_line((defs["farm"]["levels"][2] as Dictionary)["effects"])
	check_eq(str(y3["text"]), "8 food a day", "farm L3 yields 8 food a day (levels replace)")
	# Town walls carry a capability effect → the flavor line, no resource colour.
	var yw := BuildPanelCore.yield_line((defs["town-walls"]["levels"][0] as Dictionary)["effects"])
	check_eq(str(yw["text"]), BuildPanelCore.CAP_FLAVOR, "a capability effect reads the flavor line")
	check_eq(str(yw["resource"]), "", "capability yield has no resource colour")


func test_yield_line_knowledge() -> void:
	var defs := DataLoader.load_domain("buildings")
	var y := BuildPanelCore.yield_line((defs["sophias-study"]["levels"][0] as Dictionary)["effects"])
	check_eq(str(y["text"]), "1 knowledge a day", "the study's knowledge effect reads a knowledge line")
	check_eq(str(y["resource"]), "knowledge", "knowledge yield is in the knowledge colour")


func test_action_build_raise_maxed() -> void:
	var defs := DataLoader.load_domain("buildings")
	var a0 := BuildPanelCore.action(defs["farm"], 0)
	check_eq(str(a0["kind"]), "build", "L0 → build")
	check_eq(int((a0["cost"] as Dictionary)["gold"]), 40, "the first build costs 40 gold")
	check_eq(int(a0["to_level"]), 1, "the first build reaches L1")
	var a1 := BuildPanelCore.action(defs["farm"], 1)
	check_eq(str(a1["kind"]), "raise", "L1 → raise")
	check_eq(int(a1["to_level"]), 2, "the raise reaches L2")
	var a3 := BuildPanelCore.action(defs["farm"], 3)
	check_eq(str(a3["kind"]), "maxed", "L3 → maxed (3 levels)")
	check_eq((a3["cost"] as Dictionary).is_empty(), true, "maxed has no cost")


func test_carry_resources_farm() -> void:
	var defs := DataLoader.load_domain("buildings")
	var carry := BuildPanelCore.carry_resources(defs["farm"])
	check_eq(carry.size(), 2, "the farm's costs use two resources")
	check_eq(str(carry[0]), "gold", "gold first (seen in L1)")
	check_eq(str(carry[1]), "stone", "stone second (seen in L2)")


func test_survey_order_covers_all_ids() -> void:
	var defs := DataLoader.load_domain("buildings")
	var order := BuildPanelCore.survey_order(defs)
	check_eq(order.size(), defs.size(), "survey order lists every building def once")
	check_eq(str(order[0]), "sophias-study", "the designed reading order leads")
	check_eq(str(order[3]), "town-walls", "the dormant town-walls def gets a row too")
	# Determinism: the same defs always produce the same order.
	check_eq(order, BuildPanelCore.survey_order(defs), "survey order is deterministic")
