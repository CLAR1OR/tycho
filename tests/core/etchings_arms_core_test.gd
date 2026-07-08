extends "res://tests/test_suite.gd"
## Tests EtchingsArmsCore (src/town/etchings_arms_core.gd) — the "arms" panel's pure display
## helpers: which ability a site shows (equipped-else-starter) and its menu action.

const STARTERS := {"rmb": "push", "q": "snare", "r": "shockwave"}


func _etch(slots: Dictionary, unlocked: Dictionary) -> Dictionary:
	return {"slots": slots, "unlocked": unlocked}


func test_displayed_equipped_wins_over_starter() -> void:
	# An old save with Bolt equipped on RMB must render Bolt, not the Push starter.
	var etch := _etch({"rmb": "bolt", "q": "", "r": ""}, {"bolt": 1})
	check_eq(EtchingsArmsCore.displayed_ability("rmb", etch, STARTERS), "bolt",
		"equipped ability beats the starter")


func test_displayed_starter_fallback() -> void:
	var etch := _etch({"rmb": "", "q": "", "r": ""}, {})
	check_eq(EtchingsArmsCore.displayed_ability("q", etch, STARTERS), "snare",
		"empty slot falls back to the slot's starter")
	check_eq(EtchingsArmsCore.displayed_ability("r", etch, STARTERS), "shockwave",
		"R starter is shockwave")


func test_menu_action_awaken() -> void:
	var defs := DataLoader.load_domain("etchings")
	var etch := _etch({"rmb": "", "q": "", "r": ""}, {})  # snare dormant
	var a := EtchingsArmsCore.menu_action(defs["snare"], etch)
	check_eq(str(a["kind"]), "awaken", "dormant → awaken")
	check_eq(int(a["cost"]), 4, "awaken cost = snare unlock cost (4)")
	check_eq(int(a["to_level"]), 1, "awaken reaches L1")


func test_menu_action_deepen_progression() -> void:
	var defs := DataLoader.load_domain("etchings")
	var etch1 := _etch({"rmb": "shockwave", "q": "", "r": ""}, {"shockwave": 1})
	var a1 := EtchingsArmsCore.menu_action(defs["shockwave"], etch1)
	check_eq(str(a1["kind"]), "deepen", "L1 → deepen")
	check_eq(int(a1["cost"]), 6, "deepen L1→L2 cost (6)")
	check_eq(int(a1["to_level"]), 2, "deepen reaches L2")
	var etch2 := _etch({"rmb": "shockwave", "q": "", "r": ""}, {"shockwave": 2})
	var a2 := EtchingsArmsCore.menu_action(defs["shockwave"], etch2)
	check_eq(int(a2["cost"]), 9, "deepen L2→L3 cost (9)")


func test_menu_action_mastered_at_max() -> void:
	var defs := DataLoader.load_domain("etchings")
	var etch := _etch({"rmb": "push", "q": "", "r": ""}, {"push": 3})
	var a := EtchingsArmsCore.menu_action(defs["push"], etch)
	check_eq(str(a["kind"]), "mastered", "L3 → mastered")
	check_eq(int(a["cost"]), -1, "mastered has no cost")
