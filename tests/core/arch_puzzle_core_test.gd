extends "res://tests/test_suite.gd"
## Tests ArchPuzzleCore (src/learning/arch_puzzle_core.gd) — the scripted 3-beat
## Masonry & the Arch puzzle. Every didactic failure and the win path.


## Helper: run an action result, assert its event, return the new state.
func _step(result: Dictionary, want_event: String, msg: String) -> Dictionary:
	check_eq(str(result["event"]), want_event, msg)
	return result["state"]


## Helper: a state at the top of beat 2 (lintel already cracked, arch chosen).
func _beat2() -> Dictionary:
	var s := ArchPuzzleCore.initial_state()
	s = ArchPuzzleCore.place_lintel(s)["state"]
	s = ArchPuzzleCore.load(s)["state"]
	return (ArchPuzzleCore.choose_arch(s)["state"] as Dictionary)


## Helper: a state with the keystone seated (top of beat 3).
func _beat3() -> Dictionary:
	var s := _beat2()
	s = ArchPuzzleCore.toggle_centering(s)["state"]
	for i in ArchPuzzleCore.VOUSSOIR_COUNT:
		s = ArchPuzzleCore.place_voussoir(s, i)["state"]
	return (ArchPuzzleCore.place_keystone(s)["state"] as Dictionary)


func test_beat1_lintel_cracks() -> void:
	var s := ArchPuzzleCore.initial_state()
	check_eq(str(ArchPuzzleCore.load(s)["event"]), "load_nothing", "empty gateway: nothing to load")
	check_eq(str(ArchPuzzleCore.choose_arch(s)["event"]), "invalid", "cannot skip the lintel lesson")
	s = _step(ArchPuzzleCore.place_lintel(s), "lintel_placed", "flat slab goes across the gap")
	var r := ArchPuzzleCore.load(s)
	s = _step(r, "lintel_cracked", "loading the lintel cracks its underside")
	check(not bool(s["lintel"]) and bool(s["cracked"]), "lintel is rubble; the lesson is witnessed")
	check_eq(int(s["fails"]), 1, "the crack counts as a fail")
	s = _step(ArchPuzzleCore.choose_arch(s), "arch_chosen", "after the crack, curve the span")
	check_eq(int(s["beat"]), 2, "beat 2 reached")


func test_beat2_voussoirs_need_centering() -> void:
	var s := _beat2()
	s = _step(ArchPuzzleCore.place_voussoir(s, 0), "voussoir_placed", "left springer rests on the pier")
	var r := ArchPuzzleCore.place_voussoir(s, 1)
	s = _step(r, "voussoir_fell", "mid-ring wedge falls without centering")
	check_eq(ArchPuzzleCore.placed_count(s), 1, "the fallen wedge is not placed")
	s = _step(ArchPuzzleCore.toggle_centering(s), "centering_up", "raise the wooden frame")
	s = _step(ArchPuzzleCore.place_voussoir(s, 1), "voussoir_placed", "frame holds the mid wedge")
	check_eq(str(ArchPuzzleCore.place_voussoir(s, 1)["event"]), "invalid", "slot already filled")


func test_beat2_centering_pulled_early_drops_ring() -> void:
	var s := _beat2()
	s = ArchPuzzleCore.toggle_centering(s)["state"]
	for i in [0, 1, 2, 3]:
		s = ArchPuzzleCore.place_voussoir(s, i)["state"]
	s = _step(ArchPuzzleCore.toggle_centering(s), "ring_fell", "pulling the frame drops the half-ring")
	check_eq(ArchPuzzleCore.placed_count(s), 2, "only the springers survive")
	check(not bool(s["centering"]), "the frame is down")


func test_beat2_keystone_must_come_last() -> void:
	var s := _beat2()
	s = ArchPuzzleCore.toggle_centering(s)["state"]
	s = _step(ArchPuzzleCore.place_keystone(s), "keystone_fell", "keystone with no ring to bear on falls")
	for i in ArchPuzzleCore.VOUSSOIR_COUNT:
		s = ArchPuzzleCore.place_voussoir(s, i)["state"]
	s = _step(ArchPuzzleCore.place_keystone(s), "keystone_seated", "full ring takes the keystone")
	check_eq(int(s["beat"]), 3, "beat 3 reached")
	check(not bool(s["centering"]), "seating the keystone pulls the frame away")


func test_beat2_unkeyed_load_collapses() -> void:
	var s := _beat2()
	s = ArchPuzzleCore.toggle_centering(s)["state"]
	for i in [0, 1, 2]:
		s = ArchPuzzleCore.place_voussoir(s, i)["state"]
	s = _step(ArchPuzzleCore.load(s), "unkeyed_collapse", "loading before the keystone collapses the ring")
	check_eq(ArchPuzzleCore.placed_count(s), 0, "all placed stones fell")
	check(bool(s["centering"]), "the frame itself survives")
	check_eq(int(s["beat"]), 2, "still beat 2 — rebuild")


func test_beat3_unbraced_arch_splays() -> void:
	var s := _beat3()
	var r := ArchPuzzleCore.load(s)
	s = _step(r, "splayed", "unbraced arch shoves outward and falls")
	check(not bool(s["keystone"]) and ArchPuzzleCore.placed_count(s) == 0, "the ring is down")
	check_eq(int(s["beat"]), 2, "back to beat 2 to rebuild")
	# One abutment is not enough — the OTHER foot still slides.
	s = ArchPuzzleCore.place_abutment(s, "left")["state"]
	s = ArchPuzzleCore.toggle_centering(s)["state"]
	for i in ArchPuzzleCore.VOUSSOIR_COUNT:
		s = ArchPuzzleCore.place_voussoir(s, i)["state"]
	s = ArchPuzzleCore.place_keystone(s)["state"]
	s = _step(ArchPuzzleCore.load(s), "splayed", "one braced foot still splays")


func test_win_path() -> void:
	var s := _beat3()
	s = _step(ArchPuzzleCore.place_abutment(s, "left"), "abutment_placed", "left foot braced")
	s = _step(ArchPuzzleCore.place_abutment(s, "right"), "abutment_placed", "right foot braced")
	check_eq(str(ArchPuzzleCore.place_abutment(s, "left")["event"]), "invalid", "no double abutment")
	s = _step(ArchPuzzleCore.load(s), "holds", "keystone + both feet braced: it holds")
	check(bool(s["solved"]), "puzzle solved")
	check_eq(int(s["beat"]), 4, "beat 4 = done")
	check_eq(str(ArchPuzzleCore.load(s)["event"]), "invalid", "no loading a solved gateway")


func test_pointed_profile_toggle() -> void:
	var s := _beat2()
	s = _step(ArchPuzzleCore.toggle_pointed(s), "profile_pointed", "profile chosen before building")
	s = _step(ArchPuzzleCore.toggle_pointed(s), "profile_round", "and back")
	s = ArchPuzzleCore.place_voussoir(s, 0)["state"]
	check_eq(str(ArchPuzzleCore.toggle_pointed(s)["event"]), "invalid",
		"no re-cutting a ring that is already going up")


func test_actions_are_pure() -> void:
	var s := ArchPuzzleCore.initial_state()
	var before := str(s)
	ArchPuzzleCore.place_lintel(s)
	ArchPuzzleCore.load(s)
	ArchPuzzleCore.toggle_centering(s)
	check_eq(str(s), before, "actions never mutate the input state")
