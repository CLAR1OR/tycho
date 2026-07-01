extends "res://tests/test_suite.gd"
## Tests DataLoader (src/core/data_loader.gd) against the REAL data/ content —
## doubles as a content lint: if someone commits a broken JSON entry, this fails.


func test_resources_domain_loads() -> void:
	var resources := DataLoader.load_domain("resources")
	check(resources.size() >= 4, "sample resources load (got %d)" % resources.size())
	for id in ["gold", "knowledge", "stone", "resonance-ore"]:
		check(resources.has(id), "resource \"%s\" present" % id)
	if resources.has("gold"):
		check_eq(resources["gold"]["role"], "money", "gold parsed with its role")


func test_ages_domain_loads() -> void:
	var ages := DataLoader.load_domain("ages")
	check(ages.has("1"), "age 1 present (int id keyed as string)")
	if ages.has("1"):
		check_eq(ages["1"]["name"], "Medieval", "age 1 parsed")


func test_unknown_domain_is_loud_but_safe() -> void:
	# push_error fires (visible in output), but the return value must be safe.
	var out := DataLoader.load_domain("no-such-domain")
	check_eq(out.size(), 0, "unknown domain returns empty dict")
