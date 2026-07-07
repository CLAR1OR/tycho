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


func test_a3_twin_pair_priority_then_suppression() -> void:
	# The A3 opening-scene twin pair (2026-07-07): a3-first-death (deaths>=1, priority
	# 105) and a3-first-return (runs>=1, priority 104), both force_play, both setting
	# `a3`. After a death BOTH gates hold (a death still ticks runs) → the higher-priority
	# death variant wins the one force-play slot. After a deathless first run only the
	# generic is eligible. Either sets `a3`, and the shared-flag suppression then silences
	# the other forever.
	var death := _def("a3-first-death", {"source": "spine", "force_play": true,
		"priority": 105, "sets_flag": "a3", "speakers": ["tycho", "sophia"],
		"conditions": [{"counter": "deaths", "gte": 1}]})
	var ret := _def("a3-first-return", {"source": "spine", "force_play": true,
		"priority": 104, "sets_flag": "a3", "speakers": ["tycho", "sophia"],
		"conditions": [{"counter": "runs", "gte": 1}]})
	var defs := {"a3-first-death": death, "a3-first-return": ret}
	# After a death (deaths>=1, runs>=1): both eligible → priority 105 wins.
	var died := _save_state()
	died["story"]["flags"] = {}
	died["story"]["counters"] = {"runs": 1, "deaths": 1, "boss_kills": 0, "full_clears": 0}
	check(DialogueCore.eligible(death, died), "death variant eligible after a death")
	check(DialogueCore.eligible(ret, died), "generic also eligible after a death (runs ticked too)")
	check_eq(DialogueCore.select_forced(defs, died), "a3-first-death",
		"a death → the higher-priority death variant claims the force-play slot")
	# A deathless first run (runs>=1, deaths==0): only the generic is eligible.
	var won := _save_state()
	won["story"]["flags"] = {}
	won["story"]["counters"] = {"runs": 1, "deaths": 0, "boss_kills": 3, "full_clears": 1}
	check(not DialogueCore.eligible(death, won), "death variant out on a deathless run")
	check_eq(DialogueCore.select_forced(defs, won), "a3-first-return",
		"a deathless first run → the generic opener plays")
	# Whichever plays sets `a3`; now BOTH are inert (no forced scene remains), even after
	# a later death would satisfy the death variant's own gate.
	won["story"] = DialogueCore.mark_shown(won["story"], ret, false)
	won["story"]["counters"]["deaths"] = 1  # a death happens later
	check(not DialogueCore.eligible(death, won), "death variant suppressed by the shared a3 flag")
	check(not DialogueCore.eligible(ret, won), "played generic suppressed (seen + flag)")
	check_eq(DialogueCore.select_forced(defs, won), "",
		"once a3 is set, neither twin can force-play again")


func test_indicator_for() -> void:
	# "!!" = an unseen SPINE beat, "!" = unseen arc/contextual, "" = nothing new.
	var s := _save_state()
	check_eq(DialogueCore.indicator_for({"x": _def("x", {"source": "spine"})}, s, "herzog"), "!!",
		"unseen spine beat → !!")
	check_eq(DialogueCore.indicator_for({"x": _def("x", {"source": "arc"})}, s, "herzog"), "!",
		"unseen arc beat → !")
	check_eq(DialogueCore.indicator_for({"x": _def("x", {"source": "contextual"})}, s, "herzog"), "!",
		"unseen contextual → !")
	check_eq(DialogueCore.indicator_for({"x": _def("x", {"source": "bark"})}, s, "herzog"), "",
		"only a repeatable bark on offer → no marker")
	check_eq(DialogueCore.indicator_for({}, s, "herzog"), "", "nothing eligible → no marker")
	# A seen once-beat is filtered out by select → no marker.
	(s["story"]["seen"] as Array).append("seen-spine")
	check_eq(DialogueCore.indicator_for({"seen-spine": _def("seen-spine", {"source": "spine"})}, s,
		"herzog"), "", "seen once-beat → no marker")
	# A repeatable (once:false) non-bark that's already been seen slips past select's
	# seen-filter, but the marker is for NEW content only — still "".
	var s2 := _save_state()
	(s2["story"]["seen"] as Array).append("repeat-ctx")
	check_eq(DialogueCore.indicator_for(
		{"repeat-ctx": _def("repeat-ctx", {"source": "contextual", "once": false})}, s2, "herzog"),
		"", "repeatable non-bark already seen → no marker")
	# Spine still wins over a high-weight bark on the same character → !!.
	check_eq(DialogueCore.indicator_for({
		"bark-1": _def("bark-1", {"source": "bark", "priority": 999}),
		"spine-1": _def("spine-1", {"source": "spine", "priority": 1}),
	}, _save_state(), "herzog"), "!!", "unseen spine outranks a bark → !!")


func test_select_forced_priority() -> void:
	# Two eligible force_play spine beats → the higher priority takes the one slot. The
	# first-death cutscene (priority above B5) must claim it on the death-return visit.
	var s := _save_state()
	var defs := {
		"low": _def("low", {"source": "spine", "force_play": true, "priority": 95}),
		"high": _def("high", {"source": "spine", "force_play": true, "priority": 105}),
	}
	check_eq(DialogueCore.select_forced(defs, s), "high",
		"higher-priority force_play scene is chosen first")


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
