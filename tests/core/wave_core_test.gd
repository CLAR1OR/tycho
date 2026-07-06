extends "res://tests/test_suite.gd"
## Tests WaveCore (src/combat/wave_core.gd) — the pure, deterministic wave composition
## for a combat room (design 2026-07-06). All headless, no engine scene needed.


func test_deterministic() -> void:
	var a := WaveCore.compose(2, 3, 3, 777)
	var b := WaveCore.compose(2, 3, 3, 777)
	check_eq(a, b, "same inputs → identical composition")


func test_wave_count_in_range() -> void:
	for floor_i in range(1, 6):
		for room_i in range(1, 8):
			var waves := WaveCore.compose(floor_i, room_i, 3, floor_i * 100 + room_i)
			check(waves.size() >= WaveCore.MIN_WAVES and waves.size() <= WaveCore.MAX_WAVES,
				"floor %d room %d: %d waves (want %d-%d)" %
				[floor_i, room_i, waves.size(), WaveCore.MIN_WAVES, WaveCore.MAX_WAVES])


func test_third_wave_kicks_in_deeper() -> void:
	# Floor 1, room 1 is shallow (2 waves); a deep room earns the third.
	check_eq(WaveCore.wave_count(1, 1), WaveCore.MIN_WAVES, "shallow room → min waves")
	check_eq(WaveCore.wave_count(3, 3), WaveCore.MAX_WAVES, "deep room → max waves")


func test_total_beats_the_old_single_wave() -> void:
	# The old rooms spawned one wave of `base + (room-1) + (floor-1)`. Every multi-wave
	# room must field MORE bodies than that (the whole point of the change).
	for floor_i in range(1, 6):
		for room_i in range(1, 8):
			var old_count := 3 + (room_i - 1) + (floor_i - 1)
			var total := WaveCore.total_enemies(floor_i, room_i, 3)
			check(total > old_count,
				"floor %d room %d: total %d > old single-wave %d" %
				[floor_i, room_i, total, old_count])


func test_only_valid_types_emitted() -> void:
	for seed_i in 40:
		var waves := WaveCore.compose(1 + seed_i % 5, 1 + seed_i % 6, 3, seed_i)
		for wave: Array in waves:
			for t in wave:
				check(WaveCore.TYPES.has(str(t)), "seed %d: emitted a known type (%s)" % [seed_i, t])


func test_new_types_can_appear_from_floor_one() -> void:
	# Slammer and Charger are lightly weighted but MUST be reachable from floor 1 across
	# seeds (the human wants them in the mix, not gated).
	var saw_slammer := false
	var saw_charger := false
	for seed_i in 200:
		var waves := WaveCore.compose(1, 1 + seed_i % 5, 3, seed_i)
		for wave: Array in waves:
			if wave.has(WaveCore.TYPE_SLAMMER):
				saw_slammer = true
			if wave.has(WaveCore.TYPE_CHARGER):
				saw_charger = true
	check(saw_slammer, "the Slammer appears in floor-1 compositions")
	check(saw_charger, "the Charger appears in floor-1 compositions")


func test_wave_sizes_grow() -> void:
	# Later waves are at least as big as earlier ones (ramping pressure).
	var waves := WaveCore.compose(2, 2, 3, 11)
	for w in range(1, waves.size()):
		check((waves[w] as Array).size() >= (waves[w - 1] as Array).size(),
			"wave %d is not smaller than wave %d" % [w, w - 1])
