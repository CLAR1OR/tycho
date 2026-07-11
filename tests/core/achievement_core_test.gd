extends TestSuite
## Unit tests for AchievementCore (src/core/achievement_core.gd) — the pure
## EventBus-driven achievement evaluator (architecture-schemas.md §5) — plus the
## data/achievements/ content sweep and the KNOWN_PAYLOADS-vs-EventBus mirror.


func _def(event: String, where: Dictionary = {}, count: int = 1) -> Dictionary:
	var trigger := {"event": event, "count": count}
	if not where.is_empty():
		trigger["where"] = where
	return {"id": "t", "name": "T", "desc": "d", "icon": "T", "trigger": trigger}


# --- matches -------------------------------------------------------------------------

func test_matches_event_name() -> void:
	check(AchievementCore.matches({"event": "death"}, "death", {"source_id": "x"}),
		"bare event trigger matches its event")
	check(not AchievementCore.matches({"event": "death"}, "run_ended", {}),
		"a different event never matches")


func test_matches_equality_scalars() -> void:
	var t := {"event": "run_ended", "where": {"victory": true}}
	check(AchievementCore.matches(t, "run_ended", {"victory": true, "floor_reached": 1}),
		"bool equality clause matches")
	check(not AchievementCore.matches(t, "run_ended", {"victory": false}),
		"bool equality clause rejects a mismatch")
	var s := {"event": "boss_killed", "where": {"boss_id": "den-warden"}}
	check(AchievementCore.matches(s, "boss_killed", {"boss_id": "den-warden", "floor": 1}),
		"string equality clause matches")
	check(not AchievementCore.matches(s, "boss_killed", {"boss_id": "boss-placeholder"}),
		"string equality clause rejects a mismatch")
	# JSON parses trigger numbers as float; signals send real ints — must still match.
	var n := {"event": "age_advanced", "where": {"age": 2.0}}
	check(AchievementCore.matches(n, "age_advanced", {"age": 2}),
		"numeric equality matches across int/float (JSON float vs signal int)")


func test_matches_gte() -> void:
	var t := {"event": "run_ended", "where": {"floor_reached": {"gte": 3}}}
	check(AchievementCore.matches(t, "run_ended", {"floor_reached": 3}), "gte matches at the bound")
	check(AchievementCore.matches(t, "run_ended", {"floor_reached": 5}), "gte matches above")
	check(not AchievementCore.matches(t, "run_ended", {"floor_reached": 2}), "gte rejects below")


func test_matches_missing_payload_field_never_matches() -> void:
	var t := {"event": "run_ended", "where": {"victory": true}}
	check(not AchievementCore.matches(t, "run_ended", {}),
		"a clause on a field the payload lacks never matches")


func test_matches_multiple_clauses_all_must_hold() -> void:
	var t := {"event": "building_built", "where": {"building_id": "cathedral", "level": {"gte": 3}}}
	check(AchievementCore.matches(t, "building_built", {"building_id": "cathedral", "level": 3}),
		"both clauses holding matches")
	check(not AchievementCore.matches(t, "building_built", {"building_id": "cathedral", "level": 2}),
		"one failing clause rejects")


# --- apply_event ----------------------------------------------------------------------

func test_apply_unlocks_at_count_one() -> void:
	var defs := {"t": _def("dissolved")}
	var r := AchievementCore.apply_event({}, defs, "dissolved", {}, "2026-07-11T00:00:00")
	check_eq((r["unlocked"] as Array), ["t"], "count-1 def unlocks on the first match")
	check(bool(r["changed"]), "the unlock reports changed")
	var ach: Dictionary = r["achievements"]
	check_eq(str((ach["t"] as Dictionary)["unlocked_at"]), "2026-07-11T00:00:00",
		"unlocked_at stamped with the passed timestamp")
	check(AchievementCore.is_unlocked(ach, "t"), "is_unlocked reads the stamp")


func test_apply_progress_accumulates_and_unlocks_exactly_at_count() -> void:
	var defs := {"t": _def("dialogue_seen", {}, 3)}
	var ach := {}
	for i in 2:
		var r := AchievementCore.apply_event(ach, defs, "dialogue_seen", {"dialogue_id": "x"}, "now")
		ach = r["achievements"]
		check((r["unlocked"] as Array).is_empty(), "no unlock before count (tick %d)" % (i + 1))
		check(bool(r["changed"]), "each matching tick reports changed")
	check_eq(AchievementCore.progress_of(ach, "t"), 2, "progress accumulated to 2")
	check(not AchievementCore.is_unlocked(ach, "t"), "still locked below count")
	var r3 := AchievementCore.apply_event(ach, defs, "dialogue_seen", {"dialogue_id": "y"}, "now")
	check_eq((r3["unlocked"] as Array), ["t"], "the third tick unlocks exactly at count")
	check_eq(AchievementCore.progress_of(r3["achievements"], "t"), 3, "progress reads count at unlock")


func test_apply_already_unlocked_is_inert() -> void:
	var defs := {"t": _def("death")}
	var ach := {"t": {"progress": 1, "unlocked_at": "earlier"}}
	var r := AchievementCore.apply_event(ach, defs, "death", {"source_id": "x"}, "later")
	check(not bool(r["changed"]), "an unlocked def is inert — nothing changed")
	check((r["unlocked"] as Array).is_empty(), "no re-unlock")
	check_eq(str((r["achievements"]["t"] as Dictionary)["unlocked_at"]), "earlier",
		"the original unlock stamp is untouched")


func test_apply_non_matching_event_reports_unchanged() -> void:
	var defs := {"t": _def("boss_killed")}
	var r := AchievementCore.apply_event({}, defs, "resource_changed",
		{"id": "gold", "old_amount": 0.0, "new_amount": 5.0, "reason": "x"}, "now")
	check(not bool(r["changed"]), "a non-matching event reports unchanged (no profile write)")


func test_apply_returns_a_new_dict() -> void:
	var ach := {}
	var defs := {"t": _def("dissolved")}
	var r := AchievementCore.apply_event(ach, defs, "dissolved", {}, "now")
	check(ach.is_empty(), "the input dict is never mutated (return-a-new-dict convention)")
	check((r["achievements"] as Dictionary).has("t"), "the returned dict carries the change")


# --- validate -------------------------------------------------------------------------

func test_validate_accepts_a_good_def() -> void:
	var errors := AchievementCore.validate(
		_def("building_built", {"building_id": "cathedral", "level": {"gte": 3}}, 1))
	check(errors.is_empty(), "a well-formed def validates clean (%s)" % str(errors))


func test_validate_rejects_unknown_event() -> void:
	check(not AchievementCore.validate(_def("enemy_killed")).is_empty(),
		"an unknown trigger.event is an error (no enemy-kill signal exists)")


func test_validate_rejects_unknown_where_field() -> void:
	check(not AchievementCore.validate(_def("run_ended", {"vicotry": true})).is_empty(),
		"a where field not in the event's payload is an error (typo net)")


func test_validate_rejects_bad_count() -> void:
	check(not AchievementCore.validate(_def("death", {}, 0)).is_empty(), "count 0 is an error")
	check(not AchievementCore.validate(_def("death", {}, -3)).is_empty(), "negative count is an error")


func test_validate_rejects_malformed_gte() -> void:
	check(not AchievementCore.validate(_def("run_ended", {"floor_reached": {"gt": 2}})).is_empty(),
		"a non-gte comparison object is an error")
	check(not AchievementCore.validate(
		_def("run_ended", {"floor_reached": {"gte": 2, "extra": 1}})).is_empty(),
		"a gte object with extra keys is an error")
	check(not AchievementCore.validate(_def("run_ended", {"floor_reached": {"gte": "two"}})).is_empty(),
		"a non-numeric gte bound is an error")


# --- helpers --------------------------------------------------------------------------

func test_ui_helpers_defaults() -> void:
	check(not AchievementCore.is_unlocked({}, "missing"), "is_unlocked defaults false")
	check_eq(AchievementCore.progress_of({}, "missing"), 0, "progress_of defaults 0")
	check_eq(AchievementCore.trigger_count({"trigger": {}}), 1, "trigger_count defaults 1")
	check_eq(AchievementCore.trigger_count({"trigger": {"count": 5.0}}), 5,
		"trigger_count reads JSON floats as ints")


# --- data sweep + the EventBus mirror ---------------------------------------------------

func test_authored_defs_load_and_validate() -> void:
	var defs := DataLoader.load_domain("achievements")
	check(defs.size() >= 25, "the authored batch is in (~25; got %d)" % defs.size())
	for id: String in defs:
		var errors := AchievementCore.validate(defs[id])
		check(errors.is_empty(), "def %s validates clean (%s)" % [id, str(errors)])
	# The spread's anchors exist (the ones other docs/systems reference by name).
	check(defs.has("first-clear"), "first-clear authored (the smoke's unlock beat)")
	check(defs.has("cathedral-complete"),
		"cathedral-complete authored (closes the town-economy.md deferral)")
	check(defs.has("codex-complete"), "codex-complete authored (gte coupled to CODEX_SHARDS_MAX)")
	# data can't read consts: codex-complete's total gte must equal StoryCore.CODEX_SHARDS_MAX.
	var gte := int((((defs["codex-complete"]["trigger"] as Dictionary)["where"] as Dictionary)["total"] as Dictionary)["gte"])
	check_eq(gte, StoryCore.CODEX_SHARDS_MAX,
		"codex-complete's gte stays in sync with StoryCore.CODEX_SHARDS_MAX")


func test_known_events_are_real_eventbus_signals() -> void:
	# The autoload's signal->payload mapping is mirrored in KNOWN_PAYLOADS; a renamed or
	# removed bus signal must fail HERE, not silently never-fire. Inspect the script
	# resource (pure — no autoload instance needed).
	var bus: Script = load("res://src/autoload/event_bus.gd")
	var signal_names := {}
	for s: Dictionary in bus.get_script_signal_list():
		signal_names[str(s["name"])] = (s["args"] as Array).size()
	for event: String in AchievementCore.KNOWN_PAYLOADS:
		check(signal_names.has(event),
			"KNOWN_PAYLOADS event \"%s\" is a real EventBus signal" % event)
		if signal_names.has(event):
			check((AchievementCore.KNOWN_PAYLOADS[event] as Array).size() <= int(signal_names[event]) + 1,
				"\"%s\" payload fields fit its signal's args (stats dicts may fan out)" % event)
