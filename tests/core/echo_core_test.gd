extends "res://tests/test_suite.gd"
## Tests EchoCore (src/combat/echo_core.gd) — the pure offer generator + mod math —
## against the REAL data/echoes/ content (doubles as a content lint).


func test_echoes_domain_loads() -> void:
	var defs := DataLoader.load_domain("echoes")
	check(defs.size() >= 8, "sample echoes load (got %d)" % defs.size())
	check(defs.has("swift-step") and defs.has("tempest-stride"), "known echoes present")


func test_offer_is_deterministic_and_distinct() -> void:
	var defs := DataLoader.load_domain("echoes")
	var a := EchoCore.generate_offer(defs, [], 42, 0)
	var b := EchoCore.generate_offer(defs, [], 42, 0)
	check_eq(a.size(), 3, "offer has 3 choices")
	check(str(a) == str(b), "same seed+index → same offer")
	check(a[0] != a[1] and a[1] != a[2] and a[0] != a[2], "no duplicates within an offer")
	var c := EchoCore.generate_offer(defs, [], 42, 1)
	check(str(a) != str(c) or true, "different index may differ (no assert — just exercise)")


func test_non_stackable_leaves_pool() -> void:
	var defs := DataLoader.load_domain("echoes")
	# long-reach is non-stackable: once picked it must never be offered again.
	for i in 20:
		var offer := EchoCore.generate_offer(defs, ["long-reach"], 7, i)
		check(not offer.has("long-reach"), "picked non-stackable excluded (offer %d)" % i)
		if offer.has("long-reach"):
			return  # don't spam 20 failures


func test_synergy_requires_prereqs() -> void:
	var defs := DataLoader.load_domain("echoes")
	for i in 20:
		var offer := EchoCore.generate_offer(defs, [], 7, i)
		check(not offer.has("tempest-stride"), "synergy locked without prereqs (offer %d)" % i)
		if offer.has("tempest-stride"):
			return
	# With both prereqs picked it must be able to appear (weight 2.0, small pool).
	var seen := false
	for i in 40:
		if EchoCore.generate_offer(defs, ["swift-step", "quick-dash"], 7, i).has("tempest-stride"):
			seen = true
			break
	check(seen, "synergy appears once prereqs are picked")


func test_small_pool_shrinks_offer() -> void:
	var two := {
		"a": {"id": "a", "mods": []},
		"b": {"id": "b", "mods": []},
	}
	var offer := EchoCore.generate_offer(two, [], 1, 0)
	check_eq(offer.size(), 2, "offer shrinks to the eligible pool")
	check_eq(EchoCore.generate_offer({}, [], 1, 0).size(), 0, "empty pool → empty offer")


func test_apply_mods_math() -> void:
	var def := {
		"id": "t",
		"mods": [
			{"stat": "move_speed", "mult": 1.5},
			{"stat": "attack_damage", "add": 6},
			{"stat": "dash_cooldown", "add": -0.1, "mult": 0.5},
		],
	}
	var out := EchoCore.apply_mods({"move_speed": 7.0, "attack_damage": 25, "dash_cooldown": 0.9}, def)
	check_eq(out["move_speed"], 10.5, "mult applies")
	check_eq(out["attack_damage"], 31, "add applies and stays int")
	check(out["attack_damage"] is int, "int stat stays int")
	check_eq(out["dash_cooldown"], 0.4, "add then mult within one mod")


func test_apply_mods_unknown_stat_is_loud_but_safe() -> void:
	var def := {"id": "t", "mods": [{"stat": "no_such_stat", "add": 1}]}
	var out := EchoCore.apply_mods({"move_speed": 7.0}, def)  # push_error fires (visible)
	check_eq(out["move_speed"], 7.0, "unknown stat leaves values untouched")
