extends "res://tests/test_suite.gd"
## Tests WeaponCore (src/combat/weapon_core.gd) against the REAL data/weapons/
## content (doubles as a content lint for the three v1 weapons).


func test_weapons_domain_loads() -> void:
	var defs := DataLoader.load_domain("weapons")
	for id in ["sword", "daggers", "bow"]:
		check(defs.has(id), "weapon \"%s\" present" % id)
	if defs.has("sword"):
		check((defs["sword"]["mods"] as Array).is_empty(),
			"sword is the baseline — empty mods, feel-tuning stays authoritative")
	if defs.has("bow"):
		check_eq(str(defs["bow"]["kind"]), "ranged", "bow is ranged")
		check(defs["bow"]["projectile"] != null, "bow carries projectile stats")


func test_flat_level_state() -> void:
	var combat := {"current_weapon": "sword", "weapons": {}}
	check_eq(WeaponCore.flat_level(combat, "sword"), 0, "unforged weapon is flat 0")
	var out := WeaponCore.with_flat_level(combat, "sword", 2)
	check_eq(WeaponCore.flat_level(out, "sword"), 2, "with_flat_level sets")
	check_eq(WeaponCore.flat_level(combat, "sword"), 0, "input dict untouched (pure)")
	check((out["weapons"]["sword"]["resonance"] as Array).is_empty(),
		"resonance slot reserved in the weapon entry")


func test_flat_costs_and_damage_mult() -> void:
	var defs := DataLoader.load_domain("weapons")
	var sword: Dictionary = defs["sword"]
	check_eq(float(WeaponCore.next_flat_cost(sword, 0).get("resonance-ore", 0)), 1.0, "L1 costs 1 ore")
	check_eq(float(WeaponCore.next_flat_cost(sword, 4).get("resonance-ore", 0)), 8.0, "L5 costs 8 ore")
	check(WeaponCore.next_flat_cost(sword, 5).is_empty(), "flat track caps at 5 levels (PRD §7.2)")
	check_eq(WeaponCore.damage_mult(sword, 0), 1.0, "level 0 → no bonus")
	check_eq(WeaponCore.damage_mult(sword, 5), 1.75, "level 5 → +75%")


func test_daggers_are_relative() -> void:
	# The mod math itself is EchoCore's (tested there); here just lint the intent:
	# every daggers mod is a MULT on an existing stat — relative to the tuned kit.
	var daggers: Dictionary = DataLoader.load_domain("weapons")["daggers"]
	for mod: Dictionary in daggers["mods"]:
		check(mod.has("mult") and not mod.has("add"),
			"daggers mod on \"%s\" is relative (mult-only)" % str(mod.get("stat")))
