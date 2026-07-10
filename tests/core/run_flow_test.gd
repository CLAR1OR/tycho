extends "res://tests/test_suite.gd"
## Tests RunFlow (src/core/run_flow.gd) — the pure run/floor/room spine.

const CFG := {"floors": 2, "rooms_min": 3, "rooms_max": 3}  # fixed size → deterministic walk


func test_start_shape() -> void:
	var s := RunFlow.start(CFG, 42)
	check_eq(s["floor"], 1, "starts on floor 1")
	check_eq(s["room"], 1, "starts in room 1")
	check_eq(s["rooms_this_floor"], 3, "fixed min==max room count")
	check(not bool(s["over"]), "run not over at start")
	check_eq(RunFlow.room_kind(s), "combat", "room 1 of 3 is combat")


func test_full_clear_walk() -> void:
	var s := RunFlow.start(CFG, 42)
	s = RunFlow.advance(s)  # room 2
	check_eq(s["room"], 2, "advanced to room 2")
	s = RunFlow.advance(s)  # room 3 = boss
	check_eq(RunFlow.room_kind(s), "boss", "last room of the floor is the boss")
	s = RunFlow.advance(s)  # boss down → floor 2
	check_eq(s["floor"], 2, "boss clear advances the floor")
	check_eq(s["room"], 1, "new floor starts at room 1")
	check(not bool(s["over"]), "mid-run after floor 1")
	s = RunFlow.advance(RunFlow.advance(RunFlow.advance(s)))  # clear floor 2 incl. boss
	check(bool(s["over"]), "final boss ends the run")
	check(bool(s["victory"]), "full clear is a victory")
	check_eq(RunFlow.floor_reached(s), 2, "floor_reached reports the last floor")


func test_death_fails_run() -> void:
	var s := RunFlow.start(CFG, 42)
	s = RunFlow.advance(s)
	s = RunFlow.fail(s)
	check(bool(s["over"]), "death ends the run")
	check(not bool(s["victory"]), "death is not a victory")
	check_eq(RunFlow.floor_reached(s), 1, "died on floor 1")


func test_rooms_per_floor_deterministic_and_in_range() -> void:
	var cfg := {"floors": 5, "rooms_min": 6, "rooms_max": 10}
	var a := RunFlow.start(cfg, 7)
	var b := RunFlow.start(cfg, 7)
	check_eq(a["rooms_this_floor"], b["rooms_this_floor"], "same seed → same floor shape")
	# Walk seed 7 to floor 5, checking every floor's count stays in range.
	var s := a
	while not bool(s["over"]):
		var n := int(s["rooms_this_floor"])
		check(n >= 6 and n <= 10, "floor %d room count %d within 6-10" % [int(s["floor"]), n])
		# jump to this floor's boss, then clear it
		s["room"] = s["rooms_this_floor"]
		s = RunFlow.advance(s)
	check(bool(s["victory"]), "walked all 5 floors to a full clear")


func test_pure_no_mutation() -> void:
	var s := RunFlow.start(CFG, 1)
	var before := s.duplicate(true)
	RunFlow.advance(s)
	RunFlow.fail(s)
	check_eq(s["room"], before["room"], "advance/fail return new dicts, input untouched")
	check_eq(s["over"], before["over"], "input over-flag untouched")


func test_rooms_cleared_counter() -> void:
	# Feeds the room-scaled day tick (2026-07-10): every advance (incl. bosses) counts.
	var s := RunFlow.start(CFG, 42)
	check_eq(int(s["rooms_cleared"]), 0, "starts at 0 rooms cleared")
	s = RunFlow.advance(RunFlow.advance(s))
	check_eq(int(s["rooms_cleared"]), 2, "two clears counted")
	var failed := RunFlow.fail(s)
	check_eq(int(failed["rooms_cleared"]), 2, "death does not add a clear")
	# Old checkpoints (pre-amendment run dicts) lack the key — advance defaults it to 0.
	var old := s.duplicate(true)
	old.erase("rooms_cleared")
	var resumed := RunFlow.advance(old)
	check_eq(int(resumed["rooms_cleared"]), 1, "a run dict without the counter starts from 0")
