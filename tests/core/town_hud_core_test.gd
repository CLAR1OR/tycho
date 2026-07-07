extends "res://tests/test_suite.gd"
## Tests TownHudCore (src/town/town_hud_core.gd) — the pure town-HUD helpers: the day
## chip text, the per-resource day deltas + their projection strings, and the overnight
## toast segment list (design/ui-hud.md). All pure, headless.


# --- Day chip ------------------------------------------------------------------

func test_day_chip_pre_tick() -> void:
	check_eq(TownHudCore.day_chip_text(1, false, false), "Day 1",
		"day 1, no tick yet → just the day, no food span")
	check_eq(TownHudCore.day_chip_text(1, true, false), "Day 1",
		"well_fed is ignored before any day has ticked")


func test_day_chip_well_fed() -> void:
	# The +25% literal is derived from TownCore.WELL_FED_BONUS (0.25) so it can't drift.
	check_eq(TownHudCore.day_chip_text(4, true, true),
		"Day 4 · Well-Fed +%s%%" % str(int(TownCore.WELL_FED_BONUS * 100)),
		"a fed tick shows the derived Well-Fed bonus")


func test_day_chip_short() -> void:
	check_eq(TownHudCore.day_chip_text(4, false, true), "Day 4 · Short on food",
		"a short tick shows Short on food")


# --- Day deltas ----------------------------------------------------------------

func test_day_deltas_produced_and_food_net() -> void:
	# food produced 3, eaten 4 → net -1; stone produced 2, no upkeep → +2.
	var deltas := TownHudCore.day_deltas(
		{"produced": {"food": 3.0, "stone": 2.0}, "food_consumed": 4.0, "well_fed": false})
	check_eq(float(deltas["food"]), -1.0, "food nets produced minus consumed")
	check_eq(float(deltas["stone"]), 2.0, "a non-food resource is its raw production")


func test_day_deltas_food_absent_from_produced() -> void:
	# No farm → no food produced, but the town still eats: a pure negative.
	var deltas := TownHudCore.day_deltas(
		{"produced": {"knowledge": 1.0}, "food_consumed": 2.0, "well_fed": false})
	check_eq(float(deltas["food"]), -2.0, "food absent from produced still nets the upkeep")
	check_eq(float(deltas["knowledge"]), 1.0, "knowledge (its own effect kind) rides produced")


func test_day_deltas_empty_tick() -> void:
	check_eq(TownHudCore.day_deltas({}).size(), 0, "an empty tick → no deltas")
	check_eq(TownHudCore.day_deltas({"produced": {}, "food_consumed": 0.0}).size(), 0,
		"nothing produced, nothing eaten → no deltas")


# --- Projection text -----------------------------------------------------------

func test_projection_text() -> void:
	check_eq(TownHudCore.projection_text(3.0), "+3/d", "positive int → +3/d")
	check_eq(TownHudCore.projection_text(-2.0), "-2/d", "negative int → -2/d")
	check_eq(TownHudCore.projection_text(3.8), "+3.8/d", "non-integer keeps one decimal")
	check_eq(TownHudCore.projection_text(0.0), "", "zero delta → empty string")


# --- Toast segments ------------------------------------------------------------

func test_toast_segments_order_and_labels() -> void:
	# Display order: gold, stone, food, knowledge, then extras alphabetically
	# ("knowledge-shards" < "resonance-ore").
	var segs := TownHudCore.toast_segments({
		"produced": {
			"knowledge": 2.0, "gold": 5.0, "resonance-ore": 1.0,
			"knowledge-shards": 3.0, "food": 3.0, "stone": 4.0,
		},
		"food_consumed": 0.0, "well_fed": false,
	})
	var ids: Array = []
	for s: Dictionary in segs:
		ids.append(str(s["id"]))
	check_eq(ids, ["gold", "stone", "food", "knowledge", "knowledge-shards", "resonance-ore"],
		"ordered gold/stone/food/knowledge then extras alphabetically")
	check_eq(str(segs[0]["text"]), "+5 gold", "gold segment reads '+5 gold'")
	check_eq(str(segs[4]["text"]), "+3 shards", "knowledge-shards uses the short 'shards' label")
	check_eq(str(segs[5]["text"]), "+1 ore", "resonance-ore uses the short 'ore' label")


func test_toast_segments_eaten_only_when_positive() -> void:
	var none := TownHudCore.toast_segments(
		{"produced": {"gold": 1.0}, "food_consumed": 0.0, "well_fed": false})
	for s: Dictionary in none:
		check(str(s["id"]) != "eaten", "no 'eaten' segment when nothing was consumed")
	var eaten := TownHudCore.toast_segments(
		{"produced": {"gold": 1.0}, "food_consumed": 5.0, "well_fed": false})
	var last: Dictionary = eaten[eaten.size() - 1]
	check_eq(str(last["id"]), "eaten", "consuming food adds an 'eaten' segment")
	check_eq(str(last["text"]), "-5 eaten", "the eaten segment shows the negative amount")


func test_toast_segments_fed_only_when_well_fed() -> void:
	var not_fed := TownHudCore.toast_segments(
		{"produced": {"gold": 1.0}, "food_consumed": 0.0, "well_fed": false})
	for s: Dictionary in not_fed:
		check(str(s["id"]) != "fed", "no 'Well-Fed' segment when short")
	var fed := TownHudCore.toast_segments(
		{"produced": {"gold": 1.0}, "food_consumed": 2.0, "well_fed": true})
	var last: Dictionary = fed[fed.size() - 1]
	check_eq(str(last["id"]), "fed", "well_fed appends the 'fed' segment last")
	check_eq(str(last["text"]), "Well-Fed", "the fed segment reads 'Well-Fed'")


func test_toast_segments_dust_short_label() -> void:
	var segs := TownHudCore.toast_segments(
		{"produced": {"resonance-dust": 2.0}, "food_consumed": 0.0, "well_fed": false})
	check_eq(str(segs[0]["text"]), "+2 dust", "resonance-dust uses the short 'dust' label")
