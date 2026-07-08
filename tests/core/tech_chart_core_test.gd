extends "res://tests/test_suite.gd"
## Tests TechChartCore (src/learning/tech_chart_core.gd) — the research star chart's pure
## state grammar: node states + their precedence, edge kinds, and chart_pos passthrough /
## deterministic in-band fallback. Also lints that the two authored nodes carry positions.


func _tech(researched: Array = [], active: String = "", in_progress: Dictionary = {}) -> Dictionary:
	return {
		"researched": researched.duplicate(), "in_progress": in_progress.duplicate(),
		"auto_solve_counters": {}, "quiz_locked": {}, "active": active,
	}


func test_node_state_precedence() -> void:
	var arith := {"id": "a", "prereqs": [], "cost_knowledge": 20}
	var mason := {"id": "m", "prereqs": ["a"], "cost_knowledge": 40}
	check_eq(TechChartCore.node_state(mason, _tech(), "m"), &"locked", "prereq unmet → locked")
	check_eq(TechChartCore.node_state(arith, _tech(), "a"), &"available",
		"no prereq, unfunded, inactive → available")
	check_eq(TechChartCore.node_state(arith, _tech([], "a"), "a"), &"active", "active node")
	check_eq(TechChartCore.node_state(arith, _tech([], "a", {"a": 20.0}), "a"), &"ready",
		"funded → ready beats active")
	check_eq(TechChartCore.node_state(arith, _tech([], "", {"a": 20.0}), "a"), &"ready",
		"funded but not the active node still reads ready")
	check_eq(TechChartCore.node_state(arith, _tech(["a"], "a", {"a": 20.0}), "a"), &"researched",
		"researched wins over everything")
	check_eq(TechChartCore.node_state(mason, _tech(["a"]), "m"), &"available",
		"prereq met → available")


func test_edge_kind() -> void:
	check_eq(TechChartCore.edge_kind(&"researched", &"locked"), &"lit",
		"researched prereq → lit regardless of the dependent")
	check_eq(TechChartCore.edge_kind(&"researched", &"available"), &"lit", "researched prereq → lit")
	check_eq(TechChartCore.edge_kind(&"available", &"locked"), &"dim",
		"unmet prereq + still-locked dependent → dim")
	check_eq(TechChartCore.edge_kind(&"available", &"available"), &"open", "both available → open")
	check_eq(TechChartCore.edge_kind(&"ready", &"ready"), &"open",
		"funded (not researched) prereq, open dependent → open")


func test_chart_pos_passthrough() -> void:
	var def := {"chart_pos": [0.3, 0.6]}
	check(TechChartCore.has_chart_pos(def), "has_chart_pos true when a valid pair is present")
	check(TechChartCore.chart_pos(def, "x").is_equal_approx(Vector2(0.3, 0.6)),
		"authored chart_pos passes straight through")


func test_chart_pos_fallback_deterministic() -> void:
	var def := {}
	check(not TechChartCore.has_chart_pos(def), "has_chart_pos false when absent")
	var p1 := TechChartCore.chart_pos(def, "some-node")
	var p2 := TechChartCore.chart_pos(def, "some-node")
	check(p1.is_equal_approx(p2), "same id → same fallback position")
	check(p1.x >= 0.1 and p1.x <= 0.55, "fallback x sits in the safe band")
	check(p1.y >= 0.15 and p1.y <= 0.8, "fallback y sits in the safe band")
	check(not p1.is_equal_approx(TechChartCore.chart_pos(def, "other-node")),
		"different ids → different fallback positions")
	# A malformed chart_pos (wrong length) also falls back, never crashes.
	check(not TechChartCore.has_chart_pos({"chart_pos": [0.5]}), "a 1-element chart_pos is invalid")


func test_real_data_positions() -> void:
	var defs := DataLoader.load_domain("tech")
	check(TechChartCore.has_chart_pos(defs["med-arithmetic-zero"]), "arithmetic authored a chart_pos")
	check(TechChartCore.has_chart_pos(defs["med-masonry-arch"]), "masonry authored a chart_pos")
