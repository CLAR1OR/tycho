extends "res://tests/test_suite.gd"
## Tests DialogueCore (src/dialogue/dialogue_core.gd) — the act1-story-beats.md
## condition vocabulary and the selection rules, over synthetic defs + save state.


func _save_state() -> Dictionary:
	return {
		"story": {
			"flags": {"a4": true, "has-resonance-ore": true},
			"counters": {"runs": 10, "deaths": 2, "boss_kills": 3, "full_clears": 1},
			"seen": [],
			"talked_to": {"thomas": 2},
			"dialogue_last": {},
			"arc_last": {},
		},
		"tech": {"researched": ["med-arithmetic-zero"], "in_progress": {"med-masonry-arch": 5.0}},
		"ledger": {"gold": 80.0},
		"town": {"age": 1, "buildings": [{"id": "sophias-study", "level": 2}]},
		"codex": {"shards": 2},
	}


func _def(id: String, overrides: Dictionary = {}) -> Dictionary:
	var d := {"id": id, "source": "contextual", "speakers": ["herzog"], "priority": 10,
		"conditions": [], "scene": {"kind": "talk", "lines": []}}
	d.merge(overrides, true)
	return d


func test_condition_vocabulary() -> void:
	var s := _save_state()
	check(DialogueCore.eval_condition({"flag": "a4"}, s), "flag set")
	check(not DialogueCore.eval_condition({"flag": "d3"}, s), "flag unset")
	check(DialogueCore.eval_condition({"counter": "runs", "gte": 10}, s), "counter gte hit")
	check(not DialogueCore.eval_condition({"counter": "runs", "gte": 11}, s), "counter gte miss")
	check(DialogueCore.eval_condition({"counter": "codex_shards", "gte": 2}, s),
		"codex_shards reads the codex section")
	check(DialogueCore.eval_condition({"tech": "med-arithmetic-zero"}, s), "tech researched")
	check(not DialogueCore.eval_condition({"tech": "med-masonry-arch"}, s), "tech not researched")
	check(DialogueCore.eval_condition({"tech_started": "med-masonry-arch"}, s),
		"tech_started sees in_progress")
	check(DialogueCore.eval_condition({"age": 1}, s), "age gte")
	check(not DialogueCore.eval_condition({"age": 2}, s), "age too low")
	check(DialogueCore.eval_condition({"resource": "gold", "gte": 80}, s), "resource gte")
	check(not DialogueCore.eval_condition({"resource": "gold", "gte": 81}, s), "resource miss")
	check(DialogueCore.eval_condition({"building": "sophias-study", "gte": 2}, s), "building level")
	check(not DialogueCore.eval_condition({"building": "quarry", "gte": 1}, s), "missing building")
	check(DialogueCore.eval_condition({"has": "resonance-ore"}, s), "has-flag pickup")
	check(not DialogueCore.eval_condition({"has": "stone"}, s), "never picked up")
	check(DialogueCore.eval_condition({"talked_to": "thomas", "gte": 2}, s), "talked_to gte")
	check(not DialogueCore.eval_condition({"talked_to": "wren"}, s), "never talked")


func test_all_conditions_must_hold() -> void:
	var s := _save_state()
	var def := _def("x", {"conditions": [{"flag": "a4"}, {"counter": "runs", "gte": 99}]})
	check(not DialogueCore.eligible(def, s), "one failing condition sinks the snippet")
	def["conditions"] = [{"flag": "a4"}, {"counter": "runs", "gte": 2}]
	check(DialogueCore.eligible(def, s), "all conditions holding passes")


func test_once_and_seen() -> void:
	var s := _save_state()
	var def := _def("story-beat")
	check(DialogueCore.eligible(def, s), "unseen once-snippet eligible")
	(s["story"]["seen"] as Array).append("story-beat")
	check(not DialogueCore.eligible(def, s), "seen once-snippet never repeats")
	var bark := _def("bark-1", {"source": "bark"})
	(s["story"]["seen"] as Array).append("bark-1")
	check(DialogueCore.eligible(bark, s), "barks default to repeatable")


func test_bark_cooldown() -> void:
	var s := _save_state()  # runs = 10
	var bark := _def("bark-1", {"source": "bark", "cooldown_runs": 3})
	(s["story"]["dialogue_last"] as Dictionary)["bark-1"] = 8
	check(not DialogueCore.eligible(bark, s), "2 runs since last < cooldown 3")
	(s["story"]["dialogue_last"] as Dictionary)["bark-1"] = 7
	check(DialogueCore.eligible(bark, s), "3 runs since last meets cooldown")


func test_arc_no_back_to_back() -> void:
	var s := _save_state()  # runs = 10
	var beat := _def("sophia-arc-3", {"source": "arc", "speakers": ["sophia"]})
	(s["story"]["arc_last"] as Dictionary)["sophia"] = 10
	check(not DialogueCore.eligible(beat, s), "same-arc beat blocked this run")
	(s["story"]["arc_last"] as Dictionary)["sophia"] = 9
	check(DialogueCore.eligible(beat, s), "one run later the arc may continue")


func test_selection_priority() -> void:
	var s := _save_state()
	var defs := {
		"bark-1": _def("bark-1", {"source": "bark", "priority": 999}),
		"ctx-1": _def("ctx-1", {"source": "contextual", "priority": 5}),
		"ctx-2": _def("ctx-2", {"source": "contextual", "priority": 50}),
		"spine-1": _def("spine-1", {"source": "spine", "priority": 1}),
		"other-char": _def("other-char", {"source": "spine", "speakers": ["mara"]}),
	}
	check_eq(DialogueCore.select(defs, s, "herzog"), "spine-1",
		"spine outranks everything regardless of weight")
	defs.erase("spine-1")
	check_eq(DialogueCore.select(defs, s, "herzog"), "ctx-2", "weight breaks same-source ties")
	check_eq(DialogueCore.select(defs, s, "mara"), "other-char", "offers are per-owner")
	check_eq(DialogueCore.select(defs, s, "tilly"), "", "nothing to say = empty")


func test_select_forced() -> void:
	var s := _save_state()
	var defs := {
		"quiet": _def("quiet", {"source": "spine"}),
		"banner": _def("banner", {"source": "spine", "force_play": true,
			"conditions": [{"counter": "runs", "gte": 99}]}),
	}
	check_eq(DialogueCore.select_forced(defs, s), "", "ineligible forced scene stays quiet")
	(defs["banner"] as Dictionary)["conditions"] = []
	check_eq(DialogueCore.select_forced(defs, s), "banner", "eligible forced scene fires")


func test_sets_flag_suppression() -> void:
	# A snippet whose sets_flag is already set has nothing left to say — inert. This
	# is how the two B3 twin beats (a beat + its runs>=6 fallback copy, both setting
	# "b3") never both play: once one sets the flag, the other is suppressed.
	var s := _save_state()  # boss_kills=3, runs=10 → both twins' gates hold
	var main := _def("b3-shards", {"source": "spine", "sets_flag": "b3",
		"conditions": [{"counter": "boss_kills", "gte": 3}]})
	var alt := _def("b3-shards-alt", {"source": "spine", "sets_flag": "b3",
		"conditions": [{"counter": "runs", "gte": 6}]})
	# Both eligible up front (flag unset).
	check(DialogueCore.eligible(main, s), "main twin eligible before the flag is set")
	check(DialogueCore.eligible(alt, s), "alt twin eligible before the flag is set")
	# One plays → sets b3. Now the other is inert even though its own gate still holds
	# and it was never itself marked seen.
	s["story"] = DialogueCore.mark_shown(s["story"], main, false)
	check(not DialogueCore.eligible(main, s), "played twin: suppressed (seen + flag)")
	check(not DialogueCore.eligible(alt, s), "unplayed twin: suppressed by the shared flag")


func test_twin_forced_plays_exactly_once() -> void:
	# End-to-end over select_forced: both force_play twins eligible → exactly one is
	# chosen, and after it's marked shown the pool has nothing forced left.
	var s := _save_state()
	var defs := {
		"b3-shards": _def("b3-shards", {"source": "spine", "force_play": true,
			"sets_flag": "b3", "speakers": ["sophia"],
			"conditions": [{"counter": "boss_kills", "gte": 3}]}),
		"b3-shards-alt": _def("b3-shards-alt", {"source": "spine", "force_play": true,
			"sets_flag": "b3", "speakers": ["sophia"],
			"conditions": [{"counter": "runs", "gte": 6}]}),
	}
	var first := DialogueCore.select_forced(defs, s)
	check_eq(first, "b3-shards", "id-asc tiebreak picks the primary twin first")
	s["story"] = DialogueCore.mark_shown(s["story"], defs[first], false)
	check_eq(DialogueCore.select_forced(defs, s), "",
		"after one twin plays, no forced scene remains (the other is suppressed)")


func test_mark_shown() -> void:
	var s := _save_state()
	var def := _def("b5", {"source": "arc", "sets_flag": "b5"})
	var story: Dictionary = DialogueCore.mark_shown(s["story"], def, true)
	check((story["seen"] as Array).has("b5"), "marked seen")
	check(bool((story["flags"] as Dictionary)["b5"]), "sets_flag applied")
	check_eq(int((story["dialogue_last"] as Dictionary)["b5"]), 10, "last-run stamped")
	check_eq(int((story["arc_last"] as Dictionary)["herzog"]), 10, "arc stamped for the owner")
	check_eq(int((story["talked_to"] as Dictionary)["herzog"]), 1, "talk counted")
	check(not (s["story"]["seen"] as Array).has("b5"), "input story untouched (pure)")
