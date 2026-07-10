extends "res://tests/test_suite.gd"
## Tests AttunementsCore (src/learning/attunements_core.gd) against the REAL
## data/attunements/ content (doubles as a content lint for the seven attunements).
## Passive Attunements are the persistent baseline UNDER echoes (bible, PRD §7.4).


func test_domain_loads() -> void:
	var defs := DataLoader.load_domain("attunements")
	check_eq(defs.size(), 7, "all seven attunements load")
	for id: String in ["vitality", "recovery", "quickening", "resonance-flow",
			"focus", "resilience", "attunement"]:
		check(defs.has(id), "%s authored" % id)


func test_cost_progression_and_cap() -> void:
	var defs := DataLoader.load_domain("attunements")
	var vit: Dictionary = defs["vitality"]  # costs_dust [8, 12, 16] (rebalanced 2026-07-10)
	check_eq(AttunementsCore.next_cost(vit, 0), 8, "unlock (0->1) cost")
	check_eq(AttunementsCore.next_cost(vit, 1), 12, "1->2 cost")
	check_eq(AttunementsCore.next_cost(vit, 2), 16, "2->3 cost")
	check_eq(AttunementsCore.next_cost(vit, 3), -1, "maxed = -1")


func test_deepen_caps_and_is_pure() -> void:
	var attn := {}
	attn = AttunementsCore.deepen(attn, "vitality")
	check_eq(AttunementsCore.level(attn, "vitality"), 1, "deepen 0->1")
	attn = AttunementsCore.deepen(attn, "vitality")
	attn = AttunementsCore.deepen(attn, "vitality")
	check_eq(AttunementsCore.level(attn, "vitality"), 3, "deepen reaches L3")
	attn = AttunementsCore.deepen(attn, "vitality")
	check_eq(AttunementsCore.level(attn, "vitality"), 3, "deepen caps at MAX")
	# Purity: the source dict is not mutated.
	var src := {"vitality": 1}
	var _out := AttunementsCore.deepen(src, "vitality")
	check_eq(int(src["vitality"]), 1, "deepen does not mutate its input")


func test_can_deepen_affordability() -> void:
	var defs := DataLoader.load_domain("attunements")
	var vit: Dictionary = defs["vitality"]  # L1 cost 8
	check(not AttunementsCore.can_deepen(vit, 7.0, {}), "cannot afford L1 with 7 Dust")
	check(AttunementsCore.can_deepen(vit, 8.0, {}), "can afford L1 with 8 Dust")
	check(not AttunementsCore.can_deepen(vit, 999.0, {"vitality": 3}), "maxed cannot deepen")


func test_stat_mods_match_echo_handles() -> void:
	var defs := DataLoader.load_domain("attunements")
	# Vitality L1 → a single {stat: max_health, add: 20} echo-shape mod (EchoCore handle).
	var mods := AttunementsCore.stat_mods({"vitality": 1}, defs)
	check_eq(mods.size(), 1, "one stat mod at vitality L1")
	check_eq(str((mods[0] as Dictionary)["stat"]), "max_health", "vitality targets the max-HP handle")
	check_eq(int((mods[0] as Dictionary)["add"]), 20, "vitality L1 = +20 (absolute)")
	# Absolute/replace: L2 states the total, not a delta.
	var mods2 := AttunementsCore.stat_mods({"vitality": 2}, defs)
	check_eq(int((mods2[0] as Dictionary)["add"]), 40, "vitality L2 = +40 total (absolute)")
	# Combined across multiple owned stat attunements (vitality + quickening).
	var combined := AttunementsCore.stat_mods({"vitality": 1, "quickening": 1}, defs)
	check_eq(combined.size(), 2, "two owned stat attunements → two mods")


func test_heal_on_clear_pct() -> void:
	var defs := DataLoader.load_domain("attunements")
	check_eq(AttunementsCore.heal_on_clear_pct({}, defs), 0.0, "un-owned recovery = 0")
	check_eq(AttunementsCore.heal_on_clear_pct({"recovery": 1}, defs), 0.04, "recovery L1 = 4%")
	check_eq(AttunementsCore.heal_on_clear_pct({"recovery": 2}, defs), 0.07, "recovery L2 = 7%")
	check_eq(AttunementsCore.heal_on_clear_pct({"recovery": 3}, defs), 0.10, "recovery L3 = 10%")


func test_find_rate_mult() -> void:
	var defs := DataLoader.load_domain("attunements")
	check_eq(AttunementsCore.find_rate_mult({}, defs), 1.0, "un-owned find rate = 1.0 baseline")
	check_eq(AttunementsCore.find_rate_mult({"attunement": 1}, defs), 1.1, "attunement L1 = 1.1x")
	check_eq(AttunementsCore.find_rate_mult({"attunement": 3}, defs), 1.3, "attunement L3 = 1.3x")


func test_damage_reduction() -> void:
	var defs := DataLoader.load_domain("attunements")
	check_eq(AttunementsCore.damage_reduction({}, defs), 0, "un-owned DR = 0")
	check_eq(AttunementsCore.damage_reduction({"resilience": 2}, defs), 2, "resilience L2 = 2 flat DR")


func test_ability_cooldown_mult() -> void:
	var defs := DataLoader.load_domain("attunements")
	check_eq(AttunementsCore.ability_cooldown_mult({}, defs), 1.0, "un-owned cooldown mult = 1.0")
	check_eq(AttunementsCore.ability_cooldown_mult({"resonance-flow": 1}, defs), 0.9,
		"resonance-flow L1 = 0.9x cooldowns")


func test_unknown_id_is_safe() -> void:
	var defs := DataLoader.load_domain("attunements")
	check_eq(AttunementsCore.level({}, "nope"), 0, "unknown id reads level 0")
	# An owned-but-unknown id (a stale save entry) contributes nothing and never crashes.
	var stale := {"ghost-attunement": 2}
	check_eq(AttunementsCore.stat_mods(stale, defs).size(), 0, "stale unknown id yields no mods")
	check_eq(AttunementsCore.find_rate_mult(stale, defs), 1.0, "stale unknown id keeps find rate 1.0")
	check_eq(AttunementsCore.damage_reduction(stale, defs), 0, "stale unknown id keeps DR 0")
