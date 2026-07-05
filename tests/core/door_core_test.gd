extends "res://tests/test_suite.gd"
## Tests DoorCore (src/core/door_core.gd) — the pure door-plan generator + the
## cache/peril/heal math (design/run-structure.md). All deterministic, headless.

const WEIGHTS := {"gold": 3, "ore": 2, "dust": 1, "echo": 3, "reprieve": 2}


func _sigils(offer: Array) -> Array:
	var out := []
	for d: Dictionary in offer:
		out.append(str(d["sigil"]))
	return out


# All non-boss offers of a plan (the boss offer is always the last entry).
func _non_boss(plan: Dictionary) -> Array:
	var offers: Array = plan["offers"]
	return offers.slice(0, maxi(0, offers.size() - 1))


func test_deterministic() -> void:
	var a := DoorCore.generate_plan(42, 2, 8, WEIGHTS, 0.2)
	var b := DoorCore.generate_plan(42, 2, 8, WEIGHTS, 0.2)
	check_eq(a, b, "same inputs → identical plan")
	var c := DoorCore.generate_plan(43, 2, 8, WEIGHTS, 0.2)
	check(str(a) != str(c) or true, "a different seed may differ (exercise only)")


func test_offer_sizes_and_distinct() -> void:
	for seed_i in 60:
		var plan := DoorCore.generate_plan(seed_i, 1, 8, WEIGHTS, 0.15)
		for offer: Array in _non_boss(plan):
			check(offer.size() >= 1 and offer.size() <= 2,
				"seed %d: offer has 1-2 doors (got %d)" % [seed_i, offer.size()])
			var sig := _sigils(offer)
			if sig.size() == 2:
				check(sig[0] != sig[1], "seed %d: no duplicate sigils in an offer" % seed_i)


func test_boss_door_is_last_single_and_calm() -> void:
	for seed_i in 40:
		var plan := DoorCore.generate_plan(seed_i, 3, 7, WEIGHTS, 0.5)
		var offers: Array = plan["offers"]
		var boss: Array = offers[offers.size() - 1]
		check_eq(boss.size(), 1, "seed %d: boss offer is a single door" % seed_i)
		check_eq(str(boss[0]["sigil"]), DoorCore.SIGIL_BOSS, "seed %d: last offer is the boss door" % seed_i)
		check(not bool(boss[0]["peril"]), "seed %d: the boss door is never peril" % seed_i)
		# The boss sigil never appears among the ordinary offers.
		for offer: Array in _non_boss(plan):
			check(not _sigils(offer).has(DoorCore.SIGIL_BOSS),
				"seed %d: boss sigil only on the boss door" % seed_i)


func test_pity_on_a_normal_floor() -> void:
	for seed_i in 40:
		var plan := DoorCore.generate_plan(seed_i, 2, 8, WEIGHTS, 0.2)  # 8 rooms → 6 offers
		var echoes := 0
		var reprieves := 0
		for offer: Array in _non_boss(plan):
			for s in _sigils(offer):
				if s == DoorCore.SIGIL_ECHO:
					echoes += 1
				elif s == DoorCore.SIGIL_REPRIEVE:
					reprieves += 1
		check(echoes >= DoorCore.PITY_ECHO, "seed %d: >= 2 echo doors (got %d)" % [seed_i, echoes])
		check(reprieves >= DoorCore.PITY_REPRIEVE, "seed %d: >= 1 reprieve door (got %d)" % [seed_i, reprieves])


func test_pity_degrades_on_a_tiny_floor() -> void:
	# A 2-room floor is one combat room + the boss: just a single boss offer, no
	# ordinary offers to carry pity — it must degrade without erroring.
	var plan := DoorCore.generate_plan(7, 1, 2, WEIGHTS, 0.15)
	check_eq((plan["offers"] as Array).size(), 1, "2-room floor → one offer (the boss door)")
	check_eq(_non_boss(plan).size(), 0, "no ordinary offers on a 2-room floor")
	# A 3-room floor has exactly one ordinary offer (1-2 doors) — pity guarantees what
	# fits (an echo), never more than capacity.
	for seed_i in 30:
		var p := DoorCore.generate_plan(seed_i, 1, 3, WEIGHTS, 0.15)
		check_eq(_non_boss(p).size(), 1, "seed %d: 3-room floor → one ordinary offer" % seed_i)


func test_no_sigil_three_in_a_row() -> void:
	for seed_i in 80:
		var plan := DoorCore.generate_plan(seed_i, 4, 9, WEIGHTS, 0.25)
		var offers := _non_boss(plan)
		for i in range(2, offers.size()):
			var a := _sigils(offers[i - 2])
			var b := _sigils(offers[i - 1])
			var c := _sigils(offers[i])
			for s in c:
				check(not (a.has(s) and b.has(s)),
					"seed %d: sigil '%s' not in three consecutive offers (offer %d)" % [seed_i, s, i])


func test_peril_bounds() -> void:
	# peril_chance = 0 → no peril anywhere; = 1 → every ordinary door is peril; a value
	# out of [0,1] is clamped, never crashes.
	var calm := DoorCore.generate_plan(5, 3, 8, WEIGHTS, 0.0)
	for offer: Array in _non_boss(calm):
		for d: Dictionary in offer:
			check(not bool(d["peril"]), "peril_chance 0 → no peril")
	var wild := DoorCore.generate_plan(5, 3, 8, WEIGHTS, 1.0)
	for offer: Array in _non_boss(wild):
		for d: Dictionary in offer:
			check(bool(d["peril"]), "peril_chance 1 → all peril")
	var over := DoorCore.generate_plan(5, 3, 8, WEIGHTS, 5.0)  # clamps to 1
	for offer: Array in _non_boss(over):
		for d: Dictionary in offer:
			check(bool(d["peril"]), "peril_chance > 1 clamps to all peril")


func test_cache_reward_scaling_and_peril() -> void:
	var g1 := DoorCore.cache_reward("gold", 1, false)
	check_eq(str(g1["resource"]), "gold", "gold sigil pays gold")
	check_eq(g1["amount"], 12.0, "floor-1 gold cache = base")
	var g3 := DoorCore.cache_reward("gold", 3, false)
	check_eq(g3["amount"], 24.0, "floor-3 gold cache = base + 2*per-floor")
	var g3p := DoorCore.cache_reward("gold", 3, true)
	check_eq(g3p["amount"], 48.0, "peril doubles the cache")
	check_eq(str(DoorCore.cache_reward("ore", 1, false)["resource"]), "resonance-ore", "ore → resonance-ore")
	check_eq(str(DoorCore.cache_reward("dust", 1, false)["resource"]), "resonance-dust", "dust → resonance-dust")
	check(DoorCore.cache_reward("echo", 1, false).is_empty(), "echo pays no cache")
	check(DoorCore.cache_reward("reprieve", 1, false).is_empty(), "reprieve pays no cache")
	check(DoorCore.cache_reward("boss", 1, false).is_empty(), "boss pays no cache")


func test_peril_stat_mults() -> void:
	check_eq(DoorCore.peril_hp(60), 90, "peril hp = 1.5x")
	check_eq(DoorCore.peril_damage(20), 25, "peril damage = 1.25x")
	check(DoorCore.peril_hp(1) >= 1, "peril hp never below 1")


func test_heal_missing_math() -> void:
	check_eq(DoorCore.heal_missing(60, 100, 0.40), 16, "wellspring heals 40% of 40 missing")
	check_eq(DoorCore.heal_missing(60, 100, 0.30), 12, "boss heals 30% of 40 missing")
	check_eq(DoorCore.heal_missing(100, 100, 0.40), 0, "full HP → no heal")
	check_eq(DoorCore.heal_missing(1, 100, 0.30), 30, "30% of 99 missing")


func test_offer_for_room_indexing() -> void:
	var plan := DoorCore.generate_plan(9, 1, 4, WEIGHTS, 0.15)  # 4 rooms → 3 offers
	check_eq(DoorCore.offer_for_room(plan, 1), (plan["offers"] as Array)[0], "clearing room 1 shows offer[0]")
	var boss := DoorCore.offer_for_room(plan, 3)  # clearing room 3 → the boss door
	check_eq(str(boss[0]["sigil"]), DoorCore.SIGIL_BOSS, "the room before the boss shows the boss door")
	check(DoorCore.offer_for_room(plan, 4).is_empty(), "the boss room itself has no outgoing offer")
