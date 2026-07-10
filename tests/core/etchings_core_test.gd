extends "res://tests/test_suite.gd"
## Tests EtchingsCore (src/learning/etchings_core.gd) against the REAL data/etchings/
## content (doubles as a content lint for the 9 authored abilities).


func _fresh() -> Dictionary:
	return {"slots": {"rmb": "", "q": "", "r": ""}, "unlocked": {}}


func test_domain_loads() -> void:
	var defs := DataLoader.load_domain("etchings")
	check_eq(defs.size(), 9, "all nine etchings load")
	for id: String in ["push", "bolt", "afterstrike", "snare", "ward", "lodestone",
			"shockwave", "surge", "sentinel"]:
		check(defs.has(id), "%s authored" % id)
	check_eq(str(defs["push"].get("granted_by", "")), "b2", "Push is granted at B2")
	check_eq(defs["push"].get("cost_unlock_dust"), 0, "Push unlock is free")
	check(bool(defs["sentinel"].get("summon_seed", false)), "Sentinel carries the summon seed")
	check(not bool(defs["push"].get("summon_seed", true)), "Push is not a summon seed")


func test_implemented_split() -> void:
	# Five built, four dormant — implementation status is CODE, not data.
	check(EtchingsCore.is_implemented("push"), "push implemented")
	check(EtchingsCore.is_implemented("shockwave"), "shockwave implemented")
	check(not EtchingsCore.is_implemented("sentinel"), "sentinel dormant")
	check(not EtchingsCore.is_implemented("ward"), "ward dormant")


func test_learn_cost_progression() -> void:
	var defs := DataLoader.load_domain("etchings")
	var bolt: Dictionary = defs["bolt"]  # unlock 6, levels [6, 10] (rebalanced 2026-07-10)
	check_eq(EtchingsCore.learn_cost(bolt, 0), 6, "unlock cost")
	check_eq(EtchingsCore.learn_cost(bolt, 1), 6, "L2 cost")
	check_eq(EtchingsCore.learn_cost(bolt, 2), 10, "L3 cost")
	check_eq(EtchingsCore.learn_cost(bolt, 3), -1, "maxed = -1")


func test_can_learn_dormant_gate() -> void:
	var defs := DataLoader.load_domain("etchings")
	var e := _fresh()
	check(EtchingsCore.can_learn(defs["bolt"], 6.0, e), "implemented + affordable = learnable")
	check(not EtchingsCore.can_learn(defs["bolt"], 5.0, e), "can't afford = not learnable")
	check(not EtchingsCore.can_learn(defs["sentinel"], 999.0, e), "dormant never learnable, any dust")


func test_can_learn_maxed() -> void:
	var defs := DataLoader.load_domain("etchings")
	var e := _fresh()
	e["unlocked"]["bolt"] = 3
	check(not EtchingsCore.can_learn(defs["bolt"], 999.0, e), "a mastered node isn't learnable")


func test_learn_levels_up() -> void:
	var e := _fresh()
	e = EtchingsCore.learn(e, "bolt")
	check_eq(EtchingsCore.level_of(e, "bolt"), 1, "first learn = L1")
	check(EtchingsCore.is_unlocked(e, "bolt"), "and unlocked")
	e = EtchingsCore.learn(e, "bolt")
	e = EtchingsCore.learn(e, "bolt")
	check_eq(EtchingsCore.level_of(e, "bolt"), 3, "levels up to 3")
	e = EtchingsCore.learn(e, "bolt")
	check_eq(EtchingsCore.level_of(e, "bolt"), 3, "capped at MAX_LEVEL")


func test_equip_rules() -> void:
	var defs := DataLoader.load_domain("etchings")
	var e := _fresh()
	e = EtchingsCore.equip(e, "q", "snare", defs)
	check_eq(str(e["slots"]["q"]), "", "can't equip a locked etching")
	e = EtchingsCore.learn(e, "snare")
	e = EtchingsCore.equip(e, "q", "snare", defs)
	check_eq(str(e["slots"]["q"]), "snare", "unlocked etching equips into its slot")
	e = EtchingsCore.equip(e, "rmb", "snare", defs)
	check_eq(str(e["slots"]["rmb"]), "", "a Q ability can't go in the RMB slot")
	e = EtchingsCore.equip(e, "q", "", defs)
	check_eq(str(e["slots"]["q"]), "", "empty string unequips")


func test_ensure_baseline() -> void:
	var defs := DataLoader.load_domain("etchings")
	var no_b2 := EtchingsCore.ensure_baseline(_fresh(), defs, {})
	check(not EtchingsCore.is_unlocked(no_b2, "push"), "no B2 → no Push")
	var e := EtchingsCore.ensure_baseline(_fresh(), defs, {"b2": true})
	check_eq(EtchingsCore.level_of(e, "push"), 1, "B2 grants Push at L1")
	check_eq(str(e["slots"]["rmb"]), "push", "B2 auto-equips Push to RMB")
	# Idempotent: a second pass changes nothing and never re-levels Push.
	var again := EtchingsCore.ensure_baseline(e, defs, {"b2": true})
	check_eq(EtchingsCore.level_of(again, "push"), 1, "baseline is idempotent (no re-level)")
	# Never clobber a hand-chosen RMB.
	var custom := EtchingsCore.learn(_fresh(), "bolt")
	custom = EtchingsCore.equip(custom, "rmb", "bolt", defs)
	custom = EtchingsCore.ensure_baseline(custom, defs, {"b2": true})
	check_eq(str(custom["slots"]["rmb"]), "bolt", "baseline won't override an occupied RMB slot")


func test_effective_behavior() -> void:
	var defs := DataLoader.load_domain("etchings")
	var push: Dictionary = defs["push"]
	var l1 := EtchingsCore.effective_behavior(push, 1)
	check_eq(float(l1["cone_deg"]), 100.0, "L1 = base behavior")
	var l2 := EtchingsCore.effective_behavior(push, 2)
	check_eq(float(l2["cone_deg"]), 130.0, "L2 folds cone_deg_mult (100 * 1.3)")
	# L3 rider carries no _mult → nothing extra applied over L2.
	var l3 := EtchingsCore.effective_behavior(push, 3)
	check_eq(float(l3["cone_deg"]), 130.0, "L3 rider is unimplemented — no further scaling")
