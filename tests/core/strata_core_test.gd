extends "res://tests/test_suite.gd"
## Tests StrataCore (src/combat/strata_core.gd) — the pure, deterministic strata logic
## (design/dungeon-strata.md): hazard plans, placement scatter, environment defaults-
## merge. Plus data-integrity checks over data/floors + data/hazards. All headless.

const ALLOWED_KINDS := ["vent", "node", "burst", "beam", "drift", "mist"]

# A high-density fixture profile so plans are reliably non-empty for shape tests.
func _dense_profile() -> Dictionary:
	return {
		"id": 3,
		"hazards": {
			"signature": "burst-crystal",
			"pool": ["vent-plate", "denial-mist"],
			"density": {"early_rooms": 2.0, "late_rooms": 2.0},
		},
	}


func test_plan_deterministic() -> void:
	var p := _dense_profile()
	var a := StrataCore.hazard_plan(p, 2, 5, true, 777)
	var b := StrataCore.hazard_plan(p, 2, 5, true, 777)
	check_eq(a, b, "same inputs → identical hazard plan")


func test_reprieve_and_boss_get_no_hazards() -> void:
	var p := _dense_profile()
	check(StrataCore.hazard_plan(p, 2, 5, false, 1).is_empty(),
		"a non-combat room (reprieve/boss) gets no hazards")
	# A profile with no hazards block never produces hazards either.
	check(StrataCore.hazard_plan({"id": 1}, 2, 5, true, 1).is_empty(),
		"a floor with no hazards block gets no hazards")


func test_signature_is_first() -> void:
	# Density 2.0 flat → every combat room draws >= 2 hazards; the first is the signature.
	var p := _dense_profile()
	for seed_i in 60:
		var plan := StrataCore.hazard_plan(p, 3, 5, true, seed_i)
		check(plan.size() >= 1 and plan[0] == "burst-crystal",
			"seed %d: signature drawn first (%s)" % [seed_i, plan])


func test_density_rises_with_depth() -> void:
	# Late rooms field at least as many hazards as early rooms, summed over many seeds.
	var p := {
		"id": 2,
		"hazards": {
			"signature": "watcher-node", "pool": ["vent-plate"],
			"density": {"early_rooms": 0.2, "late_rooms": 0.8},
		},
	}
	var early_total := 0
	var late_total := 0
	for seed_i in 400:
		early_total += StrataCore.hazard_plan(p, 1, 5, true, seed_i).size()
		late_total += StrataCore.hazard_plan(p, 5, 5, true, seed_i).size()
	check(late_total > early_total,
		"late-room hazards (%d) outnumber early-room (%d) over 400 seeds" % [late_total, early_total])


func test_placement_in_bounds_keepout_and_spacing() -> void:
	var pts := StrataCore.placement_points(5, 4242, 20.0, Vector2(0.0, 18.0), 8.0, 4.0)
	check_eq(pts.size(), 5, "placement returns exactly the requested count")
	for i in pts.size():
		var p: Vector3 = pts[i]
		check(absf(p.x) <= 20.0 and absf(p.z) <= 20.0, "point %d in bounds (%s)" % [i, p])
		check(Vector2(p.x, p.z).distance_to(Vector2(0.0, 18.0)) >= 8.0 - 0.001,
			"point %d outside the spawn keep-out" % i)
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			check((pts[i] as Vector3).distance_to(pts[j]) >= 4.0 - 0.001,
				"points %d,%d respect min spacing" % [i, j])


func test_placement_deterministic() -> void:
	var a := StrataCore.placement_points(4, 99, 20.0, Vector2(0.0, 18.0), 8.0, 4.0)
	var b := StrataCore.placement_points(4, 99, 20.0, Vector2(0.0, 18.0), 8.0, 4.0)
	check_eq(a, b, "same seed → identical placement")


func test_env_defaults_merge() -> void:
	var full := StrataCore.environment_of({})
	check_eq(full["background_color"], Color(0.1, 0.09, 0.14), "empty profile → default background")
	check_eq(float(full["ambient_energy"]), 0.6, "empty profile → default ambient energy")
	check_eq(bool(full["fog_enabled"]), false, "empty profile → fog off by default")
	# A partial environment overrides only its keys; the rest stay default.
	var merged := StrataCore.environment_of({"environment": {
		"background_color": "#ff0000", "ambient_energy": 0.9, "fog_enabled": true}})
	check_eq(merged["background_color"], Color.html("#ff0000"), "partial: background overridden")
	check_eq(float(merged["ambient_energy"]), 0.9, "partial: ambient energy overridden")
	check_eq(bool(merged["fog_enabled"]), true, "partial: fog enabled overridden")
	check_eq(merged["ground_color"], Color(0.2, 0.19, 0.26), "partial: unset key keeps default")


func test_env_bad_hex_falls_back() -> void:
	var env := StrataCore.environment_of({"environment": {"background_color": "not-a-color"}})
	check_eq(env["background_color"], Color(0.1, 0.09, 0.14), "invalid hex → the default colour")


# --- Data integrity --------------------------------------------------------------

func test_all_hazard_files_valid() -> void:
	var haz := DataLoader.load_domain("hazards")
	check_eq(haz.size(), 6, "all six hazard defs load and validate (got %d)" % haz.size())
	for id: String in haz:
		check(ALLOWED_KINDS.has(str(haz[id]["kind"])),
			"hazard %s has a known kind (%s)" % [id, haz[id]["kind"]])


func test_floor_hazard_ids_exist() -> void:
	var floors := DataLoader.load_domain("floors")
	var haz := DataLoader.load_domain("hazards")
	for fid: String in floors:
		var hz: Dictionary = floors[fid].get("hazards", {})
		if hz.is_empty():
			continue
		var sig := str(hz.get("signature", ""))
		check(haz.has(sig), "floor %s signature \"%s\" exists in data/hazards" % [fid, sig])
		for pid: Variant in hz.get("pool", []):
			check(haz.has(str(pid)), "floor %s pool id \"%s\" exists in data/hazards" % [fid, pid])


func test_floor_prop_ids_known() -> void:
	# Every prop id a floor names must be buildable (StrataProps registry) — else it
	# silently vanishes from the room. (Unknown ids warn + skip at runtime; this catches
	# them at test time.)
	var floors := DataLoader.load_domain("floors")
	for fid: String in floors:
		for pid: Variant in floors[fid].get("props", []):
			check(StrataProps.PROPS.has(str(pid)),
				"floor %s prop id \"%s\" is in the StrataProps registry" % [fid, pid])
