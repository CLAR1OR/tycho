extends "res://tests/test_suite.gd"
## Tests ForgePanelCore (src/town/forge_panel_core.gd) — the anvil screen's pure helpers:
## the refine-track action (refine cost / to-level, or maxed) and the +% damage figure.
## Costs come from the real weapon data (flat.costs 6/12/20/32/50 — rebalanced
## 2026-07-10 — +15% damage per level).


func test_refine_action_unrefined() -> void:
	var defs := DataLoader.load_domain("weapons")
	var a := ForgePanelCore.refine_action(defs["sword"], 0)
	check_eq(str(a["kind"]), "refine", "L0 → refine")
	check_eq(int(a["cost"]), 6, "first refine costs 6 ore")
	check_eq(int(a["to_level"]), 1, "first refine reaches L1")


func test_refine_action_mid_track_cost_progression() -> void:
	var defs := DataLoader.load_domain("weapons")
	# flat.costs = [6, 12, 20, 32, 50] — cost of the NEXT level is costs[current_level].
	check_eq(int(ForgePanelCore.refine_action(defs["daggers"], 1)["cost"]), 12, "L1→L2 costs 12")
	check_eq(int(ForgePanelCore.refine_action(defs["daggers"], 2)["cost"]), 20, "L2→L3 costs 20")
	check_eq(int(ForgePanelCore.refine_action(defs["daggers"], 3)["cost"]), 32, "L3→L4 costs 32")
	check_eq(int(ForgePanelCore.refine_action(defs["daggers"], 4)["cost"]), 50, "L4→L5 costs 50")


func test_refine_action_maxed_at_five() -> void:
	var defs := DataLoader.load_domain("weapons")
	var a := ForgePanelCore.refine_action(defs["bow"], 5)
	check_eq(str(a["kind"]), "maxed", "L5 → maxed (5 costs = 5 levels)")
	check_eq(int(a["cost"]), 0, "maxed has no cost")
	check_eq(int(a["to_level"]), 5, "maxed stays at L5")


func test_damage_bonus_pct_math() -> void:
	var defs := DataLoader.load_domain("weapons")
	check_eq(ForgePanelCore.damage_bonus_pct(defs["sword"], 0), 0.0, "L0 → +0%")
	check_eq(ForgePanelCore.damage_bonus_pct(defs["sword"], 2), 30.0, "L2 → +30% (2 × 15%)")
	check_eq(ForgePanelCore.damage_bonus_pct(defs["sword"], 5), 75.0, "L5 → +75% (5 × 15%)")
