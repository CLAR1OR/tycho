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


# --- Expanded pool: healing + etching-mod + more stat/dash echoes (2026-07-10) ----------

## The pool grew from 8 to ~25; the new keystones are present.
func test_pool_grew_to_25() -> void:
	var defs := DataLoader.load_domain("echoes")
	check(defs.size() >= 25, "echo pool at ~25 (got %d)" % defs.size())
	for id in ["menders-rhythm", "deep-repair", "salvage", "resonant-edge", "quick-channel",
			"overcharge", "glass-cannon", "blink-step", "bloodwell", "arc-resonance"]:
		check(defs.has(id), "new echo present: %s" % id)


## Every def has the required shape and clean copy (no em dashes — the O1 desc grammar ban),
## and every mod entry carries a stat. Doubles as a content lint over the whole pool.
func test_all_defs_valid_shape_and_grammar() -> void:
	var defs := DataLoader.load_domain("echoes")
	for id: String in defs:
		var def: Dictionary = defs[id]
		check(str(def.get("id", "")) == id, "%s id matches filename" % id)
		check(not str(def.get("name", "")).is_empty(), "%s has a name" % id)
		var desc := str(def.get("desc", ""))
		check(not desc.is_empty(), "%s has a desc" % id)
		check(not desc.contains("—"), "%s desc has no em dash (%s)" % [id, desc])
		# The panel splits the desc into effect lines at ", " (drawback = a "but " clause);
		# every echo's desc must yield at least one line for the O1 mark.
		check(EchoOfferCore.effect_lines(desc).size() >= 1, "%s desc splits into >=1 effect line" % id)
		for mod: Dictionary in def.get("mods", []):
			check(not str(mod.get("stat", "")).is_empty(), "%s mod has a stat" % id)


## Synergy echoes (non-empty requires) must require >= 2 EXISTING, NON-synergy echoes.
func test_synergy_requires_are_existing_non_synergy() -> void:
	var defs := DataLoader.load_domain("echoes")
	var synergies := 0
	for id: String in defs:
		var def: Dictionary = defs[id]
		var reqs: Array = def.get("requires", [])
		if reqs.is_empty():
			continue
		synergies += 1
		check(reqs.size() >= 2, "%s (synergy) requires >= 2 (%d)" % [id, reqs.size()])
		for req: String in reqs:
			check(defs.has(req), "%s requires existing echo %s" % [id, req])
			if defs.has(req):
				check((defs[req] as Dictionary).get("requires", []).is_empty(),
					"%s requires a NON-synergy echo (%s)" % [id, req])
	check(synergies >= 3, "at least 3 synergy echoes (got %d)" % synergies)


## Healing handles map to the right player fields with the right values (via the pure math).
func test_healing_handles_apply() -> void:
	var defs := DataLoader.load_domain("echoes")
	var m := EchoCore.apply_mods({"heal_on_kill_pct": 0.0}, defs["menders-rhythm"])
	check_eq(m["heal_on_kill_pct"], 0.04, "Mender's Rhythm sets heal_on_kill_pct")
	var d := EchoCore.apply_mods({"heal_received_mult": 1.0}, defs["deep-repair"])
	check_eq(d["heal_received_mult"], 1.5, "Deep Repair sets heal_received_mult 1.5")
	var s := EchoCore.apply_mods({"heal_on_pickup_pct": 0.0}, defs["salvage"])
	check_eq(s["heal_on_pickup_pct"], 0.06, "Salvage sets heal_on_pickup_pct")


## Etching-mod handles, incl. ability_cooldown_mult folding on top of an attunement-set value.
func test_etching_mod_handles_apply() -> void:
	var defs := DataLoader.load_domain("echoes")
	var r := EchoCore.apply_mods({"ability_damage_mult": 1.0}, defs["resonant-edge"])
	check_eq(r["ability_damage_mult"], 1.25, "Resonant Edge sets ability_damage_mult 1.25")
	# Attunement (Resonance Flow) sets the cooldown mult first; the echo mult FOLDS on top.
	var q := EchoCore.apply_mods({"ability_cooldown_mult": 0.9}, defs["quick-channel"])
	check(absf(float(q["ability_cooldown_mult"]) - 0.765) < 0.0001,
		"Quick Channel folds multiplicatively onto a 0.9 attunement base (0.765)")
	var o := EchoCore.apply_mods({"ability_damage_mult": 1.0, "ability_cooldown_mult": 1.0}, defs["overcharge"])
	check_eq(o["ability_damage_mult"], 1.6, "Overcharge lifts ability damage")
	check(absf(float(o["ability_cooldown_mult"]) - 1.4) < 0.0001, "Overcharge lengthens cooldowns (drawback)")


## Weapon/stat handles land on the real player fields (int stays int, negatives allowed).
func test_stat_and_dash_handles_apply() -> void:
	var defs := DataLoader.load_domain("echoes")
	var g := EchoCore.apply_mods(
		{"attack_damage": 25, "attack_damage_finisher": 50, "max_health": 100}, defs["glass-cannon"])
	check_eq(g["attack_damage"], 35, "Glass Cannon lifts attack damage (int)")
	check(g["attack_damage"] is int, "Glass Cannon keeps damage int")
	check_eq(g["max_health"], 75, "Glass Cannon drops max health (drawback)")
	var qs := EchoCore.apply_mods({"attack_recover": 0.1}, defs["quick-strikes"])
	check(absf(float(qs["attack_recover"]) - 0.08) < 0.0001, "Quick Strikes shortens attack recovery")
	var b := EchoCore.apply_mods({"dash_cooldown": 0.9, "dash_iframes": 0.18}, defs["blink-step"])
	check(absf(float(b["dash_cooldown"]) - 0.675) < 0.0001, "Blink Step cuts dash cooldown")
	check(absf(float(b["dash_iframes"]) - 0.207) < 0.0001, "Blink Step widens dash i-frames")
