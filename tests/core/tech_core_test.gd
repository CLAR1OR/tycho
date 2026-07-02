extends "res://tests/test_suite.gd"
## Tests TechCore (src/learning/tech_core.gd) against the REAL data/tech/ content
## (doubles as a content lint for the first two authored nodes).


func _fresh_tech() -> Dictionary:
	return {"researched": [], "in_progress": {}, "auto_solve_counters": {}, "active": ""}


func test_tech_domain_loads() -> void:
	var defs := DataLoader.load_domain("tech")
	check(defs.has("med-arithmetic-zero") and defs.has("med-masonry-arch"), "authored nodes load")
	if defs.has("med-masonry-arch"):
		var quiz: Dictionary = defs["med-masonry-arch"]["puzzle"]
		check_eq(str(quiz.get("kind", "")), "quiz", "masonry carries the interim quiz")
		check((quiz["data"]["questions"] as Array).size() >= 3, "masonry quiz has questions")


func test_prereq_gating() -> void:
	var defs := DataLoader.load_domain("tech")
	var tech := _fresh_tech()
	var avail := TechCore.available(defs, tech)
	check(avail.has("med-arithmetic-zero"), "prereq-free node available")
	check(not avail.has("med-masonry-arch"), "masonry locked behind arithmetic")
	tech["researched"].append("med-arithmetic-zero")
	avail = TechCore.available(defs, tech)
	check(avail.has("med-masonry-arch"), "masonry opens once arithmetic is researched")
	check(not avail.has("med-arithmetic-zero"), "researched node no longer offered")


func test_invest_and_ready() -> void:
	var defs := DataLoader.load_domain("tech")
	var def: Dictionary = defs["med-arithmetic-zero"]  # cost 20
	var tech := _fresh_tech()
	var r := TechCore.invest(tech, def, 12.0)
	check_eq(r["accepted"], 12.0, "partial invest accepted in full")
	tech = r["tech"]
	check(not TechCore.is_ready(def, tech), "12/20 is not ready")
	r = TechCore.invest(tech, def, 50.0)
	check_eq(r["accepted"], 8.0, "overfill only accepts the missing 8")
	tech = r["tech"]
	check(TechCore.is_ready(def, tech), "20/20 is ready")
	check_eq(TechCore.invest(tech, def, 5.0)["accepted"], 0.0, "a full node accepts nothing")


func test_complete() -> void:
	var tech := _fresh_tech()
	tech["active"] = "x"
	tech["in_progress"]["x"] = 20.0
	tech["auto_solve_counters"]["x"] = 3
	tech = TechCore.complete(tech, "x")
	check((tech["researched"] as Array).has("x"), "completed node is researched")
	check(not (tech["in_progress"] as Dictionary).has("x"), "progress cleared")
	check(not (tech["auto_solve_counters"] as Dictionary).has("x"), "counter cleared")
	check_eq(str(tech["active"]), "", "active cleared")


func test_auto_solve() -> void:
	var defs := DataLoader.load_domain("tech")
	var def: Dictionary = defs["med-arithmetic-zero"]  # auto_solve_after_runs 5, cost 20
	var tech := _fresh_tech()
	for i in 5:
		tech = TechCore.tick_auto_solve(tech, "med-arithmetic-zero")
	check(not TechCore.auto_solve_ready(def, tech), "unfunded node never auto-solves")
	tech = TechCore.invest(tech, def, 20.0)["tech"]
	check(TechCore.auto_solve_ready(def, tech), "funded + 5 runs → Linnea solves it")
	check(str(TechCore.tick_auto_solve(tech, "")) == str(tech), "no active node → no tick")


func test_shards_needed() -> void:
	var r := TechCore.shards_needed(23.0, 10.0, 9.0)  # missing 23, have 10 knowledge
	check_eq(r["shards_used"], 3, "gap of 13 needs 3 shards at 5 apiece")
	check_eq(r["knowledge_from_shards"], 15.0, "3 shards → 15 knowledge")
	check_eq(TechCore.shards_needed(8.0, 20.0, 9.0)["shards_used"], 0, "no gap → no shards")
	check_eq(TechCore.shards_needed(100.0, 0.0, 2.0)["shards_used"], 2, "capped at owned shards")


func test_building_unlock_gate() -> void:
	var bdefs := DataLoader.load_domain("buildings")
	check(TownCore.is_unlocked(bdefs["linneas-study"], []), "ungated building always available")
	check(not TownCore.is_unlocked(bdefs["quarry"], []), "quarry locked without masonry")
	check(TownCore.is_unlocked(bdefs["quarry"], ["med-masonry-arch"]), "quarry opens with masonry")
	check(not TownCore.is_unlocked(bdefs["town-walls"], []), "town-walls locked without masonry")
