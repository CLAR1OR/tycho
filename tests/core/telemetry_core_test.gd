extends "res://tests/test_suite.gd"
## Unit tests for TelemetryCore: record shaping + the JSONL line format.

func test_build_record_shape() -> void:
	var r := TelemetryCore.build_record(3, 1, "victory", 5, 10, 812.5, ["dash-echo", "vital-core"], {"gold": 42.0})
	check_eq(r["run_number"], 3, "run_number passes through")
	check_eq(r["slot"], 1, "slot passes through")
	check_eq(r["outcome"], "victory", "outcome passes through")
	check_eq(r["floor_reached"], 5, "floor_reached passes through")
	check_eq(r["room_reached"], 10, "room_reached passes through")
	check_eq(r["duration_s"], 812.5, "duration_s passes through")
	check_eq(r["echo_picks"], ["dash-echo", "vital-core"], "echo_picks passes through")
	check_eq(r["resource_deltas"], {"gold": 42.0}, "resource_deltas passes through")


func test_build_record_does_not_alias_inputs() -> void:
	var picks := ["push"]
	var deltas := {"gold": 1.0}
	var r := TelemetryCore.build_record(1, 99, "death", 1, 1, 0.0, picks, deltas)
	picks.append("bolt")
	deltas["gold"] = 999.0
	check_eq(r["echo_picks"], ["push"], "record's echo_picks is a copy, unaffected by later caller mutation")
	check_eq(r["resource_deltas"], {"gold": 1.0}, "record's resource_deltas is a copy, unaffected by later caller mutation")


func test_to_line_round_trips_as_json() -> void:
	var r := TelemetryCore.build_record(2, 99, "forfeit", 2, 3, 5.25, [], {"resonance-ore": 2.0})
	var line := TelemetryCore.to_line(r)
	check(not line.contains("\n"), "one JSON line, no embedded newline")
	var parsed: Variant = JSON.parse_string(line)
	check(parsed is Dictionary, "the line parses back as a JSON object")
	check_eq((parsed as Dictionary)["outcome"], "forfeit", "round-tripped outcome matches")
	check_eq((parsed as Dictionary)["run_number"], 2, "round-tripped run_number matches")


func test_all_three_outcomes_accepted() -> void:
	for outcome in TelemetryCore.OUTCOMES:
		var r := TelemetryCore.build_record(1, 1, outcome, 1, 1, 1.0, [], {})
		check_eq(r["outcome"], outcome, "outcome \"%s\" accepted" % outcome)
	check_eq(TelemetryCore.OUTCOMES, ["victory", "death", "forfeit"], "the outcome enum is exactly these three")
