extends "res://tests/test_suite.gd"
## Tests LayoutCore (src/combat/layout_core.gd) — the pure room-layout pool logic
## (PRD §7.6): seeded picking (combat no-repeat within a floor, boss floor filter),
## geometry validation (bounds, clear zones, the flood-fill path guarantee), and the
## footprint queries. Plus a data lint over every shipped data/layouts/*.json.

# --- Fixtures ---------------------------------------------------------------------

func _combat_def(id: String) -> Dictionary:
	return {"id": id, "kind": "combat",
		"obstacles": [{"kind": "pillar", "pos": [0.0, -2.0]}]}


func _pool_defs() -> Dictionary:
	var defs := {}
	for i in 5:
		var id := "c%d" % i
		defs[id] = _combat_def(id)
	defs["r0"] = {"id": "r0", "kind": "reprieve",
		"obstacles": [{"kind": "pillar", "pos": [-14.0, -10.0]}]}
	defs["b1"] = {"id": "b1", "kind": "boss", "floor": 1, "obstacles": []}
	defs["b2"] = {"id": "b2", "kind": "boss", "floor": 2, "obstacles": []}
	return defs


# --- pick -------------------------------------------------------------------------

func test_pick_deterministic() -> void:
	var defs := _pool_defs()
	var a := LayoutCore.pick(defs, "combat", 2, 3, 777)
	var b := LayoutCore.pick(defs, "combat", 2, 3, 777)
	check_eq(a, b, "same inputs → identical pick")
	check_eq(str(LayoutCore.pick(defs, "reprieve", 1, 2, 5)["id"]), "r0",
		"a reprieve pick draws from the reprieve pool only")


func test_pick_no_repeat_within_floor() -> void:
	# 5 combat defs → rooms 1..5 must each get a DIFFERENT layout; room 6 wraps the
	# shuffled pool (same id as room 1). Different floors reshuffle.
	var defs := _pool_defs()
	var seen := {}
	for room in range(1, 6):
		var id := str(LayoutCore.pick(defs, "combat", 3, room, 42)["id"])
		check(not seen.has(id), "room %d repeats layout %s before pool exhaustion" % [room, id])
		seen[id] = true
	check_eq(seen.size(), 5, "5 rooms drew 5 distinct combat layouts")
	check_eq(str(LayoutCore.pick(defs, "combat", 3, 6, 42)["id"]),
		str(LayoutCore.pick(defs, "combat", 3, 1, 42)["id"]),
		"an exhausted pool wraps to the shuffle's start")


func test_pick_boss_floor_filter() -> void:
	var defs := _pool_defs()
	check_eq(str(LayoutCore.pick(defs, "boss", 2, 9, 1)["id"]), "b2",
		"the boss pick filters by floor")
	check(LayoutCore.pick(defs, "boss", 3, 9, 1).is_empty(),
		"a floor with no boss layout yields {} (authored fallback)")
	check(LayoutCore.pick({}, "combat", 1, 1, 1).is_empty(), "empty defs yield {}")


# --- validate: shape + zones -------------------------------------------------------

func test_validate_good_defs() -> void:
	check_eq(LayoutCore.validate(_combat_def("ok")), [], "a plain combat def validates")
	check_eq(LayoutCore.validate({"id": "b", "kind": "boss", "floor": 1,
		"obstacles": [{"kind": "pillar", "pos": [17.0, 0.0]}]}), [],
		"a boss def with perimeter obstacles validates")
	check_eq(LayoutCore.validate({"id": "blk", "kind": "combat",
		"obstacles": [{"kind": "block", "pos": [0.0, -3.0], "size": [7.0, 7.0]}]}), [],
		"a centre block (donut) validates")


func test_validate_unknown_kind_and_floor_rules() -> void:
	check(not LayoutCore.validate({"id": "x", "kind": "arena", "obstacles": []}).is_empty(),
		"an unknown kind errors")
	check(not LayoutCore.validate({"id": "x", "kind": "boss", "obstacles": []}).is_empty(),
		"a boss layout without a floor errors")
	check(not LayoutCore.validate({"id": "x", "kind": "combat", "floor": 2,
		"obstacles": []}).is_empty(), "a floor on a non-boss layout errors")
	check(not LayoutCore.validate({"id": "x", "kind": "combat"}).is_empty(),
		"missing obstacles array errors")


func test_validate_malformed_obstacles() -> void:
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "cone", "pos": [0.0, 0.0]}]}).is_empty(),
		"an unknown obstacle kind errors")
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "pillar"}]}).is_empty(), "a pillar without pos errors")
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "block", "pos": [0.0, 0.0]}]}).is_empty(),
		"a block without size errors")


func test_validate_bounds_and_door_strip() -> void:
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "pillar", "pos": [26.0, 0.0]}]}).is_empty(),
		"a footprint leaving the +-26 interior errors")
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "pillar", "pos": [0.0, -19.5]}]}).is_empty(),
		"a footprint reaching the door strip (z <= -20) errors")
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "block", "pos": [10.0, -18.0], "size": [1.6, 6.0]}]}).is_empty(),
		"a block corner reaching the door strip errors (full width)")


func test_validate_spawn_keepout() -> void:
	check(not LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "pillar", "pos": [0.0, 14.0]}]}).is_empty(),
		"a pillar inside the spawn keep-out errors")


func test_validate_wellspring_clearing() -> void:
	var obstacles := [{"kind": "pillar", "pos": [0.0, -5.5]}]
	check_eq(LayoutCore.validate({"id": "x", "kind": "combat", "obstacles": obstacles}), [],
		"a pillar near (0,-2) is fine in a COMBAT room")
	check(not LayoutCore.validate({"id": "x", "kind": "reprieve",
		"obstacles": obstacles}).is_empty(),
		"the same pillar violates the reprieve Wellspring clearing")


func test_validate_boss_band() -> void:
	check(not LayoutCore.validate({"id": "x", "kind": "boss", "floor": 1,
		"obstacles": [{"kind": "pillar", "pos": [0.0, -14.0]}]}).is_empty(),
		"an obstacle inside the boss band errors")
	check(not LayoutCore.validate({"id": "x", "kind": "boss", "floor": 1,
		"obstacles": [{"kind": "block", "pos": [14.5, -5.0], "size": [4.0, 4.0]}]}).is_empty(),
		"a block whose footprint reaches into the band errors")


# --- validate: flood fill -----------------------------------------------------------

func test_flood_fill_rejects_sealed_room() -> void:
	# One wall across the full interior seals the door line off from the spawn.
	var errors := LayoutCore.validate({"id": "x", "kind": "combat",
		"obstacles": [{"kind": "block", "pos": [0.0, -10.0], "size": [52.0, 1.6]}]})
	check(not errors.is_empty(), "a full-width wall fails validation")
	var mentions_door := false
	for e in errors:
		if "door" in e:
			mentions_door = true
	check(mentions_door, "the failure names the door-line reachability (%s)" % [errors])


func test_flood_fill_rejects_sealed_pocket() -> void:
	# Four blocks form a closed box — a sealed open pocket the player can never enter.
	var errors := LayoutCore.validate({"id": "x", "kind": "combat", "obstacles": [
		{"kind": "block", "pos": [0.0, -8.0], "size": [8.0, 1.6]},
		{"kind": "block", "pos": [0.0, 0.0], "size": [8.0, 1.6]},
		{"kind": "block", "pos": [-4.0, -4.0], "size": [1.6, 8.0]},
		{"kind": "block", "pos": [4.0, -4.0], "size": [1.6, 8.0]},
	]})
	check(not errors.is_empty(), "a sealed box pocket fails validation")
	var mentions_pocket := false
	for e in errors:
		if "pocket" in e:
			mentions_pocket = true
	check(mentions_pocket, "the failure names the sealed pocket (%s)" % [errors])


# --- footprints + blocked -----------------------------------------------------------

func test_footprints_math() -> void:
	var fps := LayoutCore.footprints({"id": "x", "kind": "combat", "obstacles": [
		{"kind": "pillar", "pos": [3.0, -4.0]},
		{"kind": "pillar", "pos": [0.0, 0.0], "radius": 2.5},
		{"kind": "block", "pos": [-5.0, 2.0], "size": [6.0, 2.0], "rot": 30},
	]})
	check_eq(fps.size(), 3, "one footprint per obstacle")
	check_eq(float(fps[0]["radius"]), LayoutCore.DEFAULT_PILLAR_RADIUS,
		"a radius-less pillar takes the default")
	check_eq(fps[0]["center"], Vector2(3.0, -4.0), "footprint centre = obstacle pos")
	check_eq(float(fps[1]["radius"]), 2.5, "an explicit pillar radius carries over")
	check(is_equal_approx(float(fps[2]["radius"]), Vector2(3.0, 1.0).length()),
		"a block footprint is the circumscribed circle (rotation-proof)")


func test_blocked_query() -> void:
	var fps := [{"center": Vector2(0.0, 0.0), "radius": 2.0}]
	check(LayoutCore.blocked(fps, Vector2(2.5, 0.0), 1.0), "inside radius+margin → blocked")
	check(not LayoutCore.blocked(fps, Vector2(3.5, 0.0), 1.0), "outside radius+margin → free")
	check(not LayoutCore.blocked([], Vector2.ZERO, 5.0), "no footprints → never blocked")


# --- Data lint: every shipped layout ------------------------------------------------

func test_all_layout_files_valid() -> void:
	var layouts := DataLoader.load_domain("layouts")
	check_eq(layouts.size(), 38, "all 38 layout defs load (got %d)" % layouts.size())
	var counts := {"combat": 0, "reprieve": 0, "boss": 0}
	var boss_floors := {}
	for id: String in layouts:
		var def: Dictionary = layouts[id]
		var errors := LayoutCore.validate(def)
		check_eq(errors, [] as Array[String], "layout %s validates (%s)" % [id, errors])
		counts[str(def["kind"])] += 1
		if str(def["kind"]) == LayoutCore.KIND_BOSS:
			var f := int(def["floor"])
			check(not boss_floors.has(f), "boss floor %d covered twice" % f)
			boss_floors[f] = id
	check_eq(int(counts["combat"]), 30, "30 combat layouts shipped")
	check_eq(int(counts["reprieve"]), 3, "3 reprieve layouts shipped")
	check_eq(int(counts["boss"]), 5, "5 boss arenas shipped")
	for f in range(1, 6):
		check(boss_floors.has(f), "boss floor %d has an arena" % f)


func test_floor1_boss_arena_clears_den_warden_vents() -> void:
	# The Den-Warden's authored arena_vents (data/bosses/den-warden.json) must each
	# clear every floor-1 arena obstacle by >= 3 m edge distance (spec rule).
	var layouts := DataLoader.load_domain("layouts")
	var arena: Dictionary = {}
	for id: String in layouts:
		if str(layouts[id]["kind"]) == LayoutCore.KIND_BOSS \
				and int(layouts[id].get("floor", 0)) == 1:
			arena = layouts[id]
	check(not arena.is_empty(), "a floor-1 boss arena exists")
	var bosses := DataLoader.load_domain("bosses")
	check(bosses.has("den-warden"), "the den-warden def exists")
	var vents: Array = bosses["den-warden"].get("arena_vents", [])
	check(not vents.is_empty(), "the den-warden has authored arena vents")
	for fp: Dictionary in LayoutCore.footprints(arena):
		for v: Array in vents:
			var clearance := Vector2(float(v[0]), float(v[1]))\
				.distance_to(fp["center"]) - float(fp["radius"])
			check(clearance >= 3.0,
				"arena obstacle at %s clears vent %s by %.1f m (< 3)"
				% [fp["center"], v, clearance])


func test_pick_covers_shipped_pool_without_repeats() -> void:
	# Against the REAL data: a 10-room floor must draw 10 distinct combat layouts.
	var layouts := DataLoader.load_domain("layouts")
	var seen := {}
	for room in range(1, 11):
		var def := LayoutCore.pick(layouts, "combat", 1, room, 20260712)
		check(not def.is_empty(), "room %d picked a combat layout" % room)
		var id := str(def["id"])
		check(not seen.has(id), "room %d repeated %s within one floor" % [room, id])
		seen[id] = true
