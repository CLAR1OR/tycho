extends TestSuite
## BossCore (design/bosses/floor-1-boss.md §2 — the boss grammar): pure phase
## selection, loop stepping, reconfigure detection, and def validation, plus a
## sweep over every authored def in data/bosses/.

const DEF := {
	"id": "test-boss",
	"phases": [
		{"threshold": 1.0, "loop": ["a", "b", "c"]},
		{"threshold": 0.5, "loop": ["d"]},
	],
	"moves": {
		"a": {"kind": "lunge"},
		"b": {"kind": "swipe"},
		"c": {"kind": "circle"},
		"d": {"kind": "burrow"},
	},
}

const DEF3 := {
	"id": "three-phase",
	"phases": [
		{"threshold": 1.0, "loop": ["a"]},
		{"threshold": 0.6, "loop": ["a"]},
		{"threshold": 0.3, "loop": ["a"]},
	],
	"moves": {"a": {"kind": "lunge"}},
}


func test_phase_for_boundaries() -> void:
	check_eq(BossCore.phase_for(DEF, 1.0), 0, "full HP = phase 1 (index 0)")
	check_eq(BossCore.phase_for(DEF, 0.51), 0, "just above the threshold stays phase 1")
	check_eq(BossCore.phase_for(DEF, 0.5), 1, "exactly 50% enters phase 2 (<= threshold)")
	check_eq(BossCore.phase_for(DEF, 0.49), 1, "below the threshold is phase 2")
	check_eq(BossCore.phase_for(DEF, 0.0), 1, "zero HP fraction stays the last phase")


func test_phase_for_three_phases() -> void:
	check_eq(BossCore.phase_for(DEF3, 0.7), 0, "0.7 sits in phase 1")
	check_eq(BossCore.phase_for(DEF3, 0.6), 1, "0.6 enters phase 2 exactly")
	check_eq(BossCore.phase_for(DEF3, 0.31), 1, "0.31 still phase 2")
	check_eq(BossCore.phase_for(DEF3, 0.3), 2, "0.3 enters phase 3 exactly")


func test_next_move_steps_and_wraps() -> void:
	var m0 := BossCore.next_move(DEF, 0, 0)
	check_eq(str(m0["id"]), "a", "loop position 0 is the first move")
	check_eq(str((m0["move"] as Dictionary)["kind"]), "lunge", "the move def rides along")
	check_eq(int(m0["next_position"]), 1, "position advances")
	var m2 := BossCore.next_move(DEF, 0, 2)
	check_eq(str(m2["id"]), "c", "loop position 2 is the last move")
	check_eq(int(m2["next_position"]), 0, "the loop wraps to its top")
	var over := BossCore.next_move(DEF, 0, 3)
	check_eq(str(over["id"]), "a", "an out-of-range position wraps by modulo")
	var p2 := BossCore.next_move(DEF, 1, 5)
	check_eq(str(p2["id"]), "d", "a single-move loop always yields its move")
	check_eq(int(p2["next_position"]), 0, "a single-move loop wraps to 0")
	check_eq(BossCore.next_move({}, 0, 0), {}, "no phases -> empty result (defensive)")


func test_should_reconfigure() -> void:
	check(BossCore.should_reconfigure(0, 1), "moving into a later phase reconfigures")
	check(not BossCore.should_reconfigure(1, 1), "staying in the phase never reconfigures")
	check(not BossCore.should_reconfigure(1, 0), "moving backwards never reconfigures")


func test_validate_accepts_good_defs() -> void:
	check(BossCore.validate(DEF).is_empty(), "the 2-phase test def validates")
	check(BossCore.validate(DEF3).is_empty(), "the 3-phase test def validates")


func test_validate_catches_broken_defs() -> void:
	check(not BossCore.validate({"id": "x", "phases": [], "moves": {}}).is_empty(),
		"zero phases is an error")
	var ascending := {"id": "x", "moves": {"a": {"kind": "lunge"}}, "phases": [
		{"threshold": 1.0, "loop": ["a"]}, {"threshold": 1.0, "loop": ["a"]}]}
	check(not BossCore.validate(ascending).is_empty(), "non-descending thresholds are an error")
	var bad_first := {"id": "x", "moves": {"a": {"kind": "lunge"}}, "phases": [
		{"threshold": 0.9, "loop": ["a"]}]}
	check(not BossCore.validate(bad_first).is_empty(), "phase 1 must start at threshold 1.0")
	var empty_loop := {"id": "x", "moves": {"a": {"kind": "lunge"}}, "phases": [
		{"threshold": 1.0, "loop": []}]}
	check(not BossCore.validate(empty_loop).is_empty(), "an empty loop is an error")
	var ghost_move := {"id": "x", "moves": {"a": {"kind": "lunge"}}, "phases": [
		{"threshold": 1.0, "loop": ["nope"]}]}
	check(not BossCore.validate(ghost_move).is_empty(), "a loop naming a missing move is an error")
	var alien_kind := {"id": "x", "moves": {"a": {"kind": "laser"}}, "phases": [
		{"threshold": 1.0, "loop": ["a"]}]}
	check(not BossCore.validate(alien_kind).is_empty(), "an unknown move kind is an error")


func test_authored_defs_validate() -> void:
	# Sweep every authored boss def — content additions must pass the sequencing rules.
	var defs := DataLoader.load_domain("bosses")
	check(defs.has("den-warden"), "data/bosses/den-warden.json loads (floor 1's boss)")
	for id: String in defs:
		var errors := BossCore.validate(defs[id])
		check(errors.is_empty(), "boss def \"%s\" validates (%s)" % [id, errors])


func test_den_warden_shape() -> void:
	var dw: Dictionary = DataLoader.load_domain("bosses").get("den-warden", {})
	check_eq(int(dw.get("floor", -1)), 1, "den-warden is floor 1's boss")
	check_eq(str(dw.get("name", "")), "The Den-Warden", "placeholder display name in place")
	var phases: Array = dw.get("phases", [])
	check_eq(phases.size(), 2, "den-warden has the single 50% threshold (2 phases)")
	check_eq(float((phases[1] as Dictionary)["threshold"]), 0.5, "phase 2 starts at 50%")
	check_eq((phases[1] as Dictionary)["loop"], ["burrow", "erupt", "vent_call"],
		"phase 2 is the burrow/erupt/vent loop")
	for v: Variant in dw.get("arena_vents", []):
		check((v as Array).size() == 2, "every arena vent is an [x, z] pair")
	check((dw.get("arena_vents", []) as Array).size() >= 1, "the arena has vent plates")


func test_def_for_floor() -> void:
	var defs := DataLoader.load_domain("bosses")
	check_eq(str(BossCore.def_for_floor(defs, 1).get("id", "")), "den-warden",
		"floor 1 resolves to the den-warden")
	check(BossCore.def_for_floor(defs, 2).is_empty(),
		"floor 2 has no def -> {} (the placeholder-boss path)")
