extends "res://tests/test_suite.gd"
## Tests HudCore (src/combat/hud_core.gd) — the pure in-run HUD helpers: info-chip
## segment rules, echo-shelf folding, the monogram scheme, and the low-HP threshold
## (design/ui-hud.md). All pure, headless.


# --- Info chip -----------------------------------------------------------------

func test_chip_normal_combat() -> void:
	check_eq(HudCore.chip_text(2, 3, 5, HudCore.KIND_COMBAT, false, 0, 1, false),
		"F2 · R3/5", "normal single-wave combat room")


func test_chip_multiwave_shows_wave() -> void:
	check_eq(HudCore.chip_text(1, 2, 5, HudCore.KIND_COMBAT, false, 1, 3, false),
		"F1 · R2/5 · Wave 2/3", "multi-wave room shows the 1-based wave segment")


func test_chip_cleared_drops_wave() -> void:
	check_eq(HudCore.chip_text(1, 2, 5, HudCore.KIND_COMBAT, false, 2, 3, true),
		"F1 · R2/5", "a cleared room hides the Wave segment")


func test_chip_boss() -> void:
	check_eq(HudCore.chip_text(5, 6, 6, HudCore.KIND_BOSS, false, 0, 0, false),
		"F5 · BOSS", "boss room shows BOSS, no room fraction, no wave")


func test_chip_reprieve() -> void:
	check_eq(HudCore.chip_text(3, 4, 5, HudCore.KIND_REPRIEVE, false, 0, 0, true),
		"F3 · Reprieve", "reprieve room shows Reprieve")


func test_chip_peril_marks_room_segment() -> void:
	check_eq(HudCore.chip_text(2, 1, 5, HudCore.KIND_COMBAT, true, 0, 1, false),
		"F2 · R1/5 ⚠", "peril appends the warning glyph to the room segment")


func test_chip_peril_with_wave() -> void:
	check_eq(HudCore.chip_text(2, 1, 5, HudCore.KIND_COMBAT, true, 0, 2, false),
		"F2 · R1/5 ⚠ · Wave 1/2", "peril glyph sits on the room segment, wave segment follows")


# --- Monogram ------------------------------------------------------------------

func test_monogram_two_words() -> void:
	check_eq(HudCore.monogram("Tempest Stride"), "TS", "two words → both initials")
	check_eq(HudCore.monogram("Vital Core"), "VC", "two words → both initials")


func test_monogram_one_word() -> void:
	check_eq(HudCore.monogram("Push"), "P", "one word → one initial")


func test_monogram_long_caps_at_two() -> void:
	check_eq(HudCore.monogram("Deep Repair Salvage Rhythm"), "DR",
		"more than two words caps at the first two initials")


func test_monogram_extra_whitespace() -> void:
	check_eq(HudCore.monogram("  Keen   Edge  "), "KE",
		"leading/trailing/inner extra whitespace is ignored")


func test_monogram_empty() -> void:
	check_eq(HudCore.monogram(""), "?", "empty name falls back to ?")


# --- Echo folding --------------------------------------------------------------

func _defs() -> Dictionary:
	return {
		"swift-step": {"id": "swift-step", "name": "Swift Step"},
		"vital-core": {"id": "vital-core", "name": "Vital Core"},
		"keen-edge": {"id": "keen-edge", "name": "Keen Edge"},
	}


func test_fold_order_is_first_pick() -> void:
	var folded := HudCore.fold_echoes(["keen-edge", "swift-step"], _defs())
	check_eq(folded.size(), 2, "two distinct picks → two tiles")
	check_eq(str(folded[0]["id"]), "keen-edge", "tile order follows first-pick order")
	check_eq(str(folded[1]["id"]), "swift-step", "second-picked id is second")
	check_eq(str(folded[0]["monogram"]), "KE", "tile carries its monogram")


func test_fold_stacks_repeats() -> void:
	var folded := HudCore.fold_echoes(["vital-core", "keen-edge", "vital-core"], _defs())
	check_eq(folded.size(), 2, "a repeated pick folds into one tile")
	check_eq(str(folded[0]["id"]), "vital-core", "the stacked id keeps its first-pick slot")
	check_eq(int(folded[0]["count"]), 2, "the fold counts the repeats")
	check_eq(int(folded[1]["count"]), 1, "the single pick stays count 1")


func test_fold_unknown_id_uses_id_as_name() -> void:
	var folded := HudCore.fold_echoes(["mystery"], _defs())
	check_eq(str(folded[0]["name"]), "mystery", "an unknown id falls back to the raw id as name")


func test_fold_empty() -> void:
	check_eq(HudCore.fold_echoes([], _defs()).size(), 0, "no picks → no tiles")


# --- Low HP --------------------------------------------------------------------

func test_low_hp_boundary() -> void:
	check(HudCore.is_low_hp(25, 100), "exactly 25% is low (inclusive threshold)")
	check(not HudCore.is_low_hp(26, 100), "26% is not low")
	check(HudCore.is_low_hp(0, 100), "0 HP is low")


func test_low_hp_guards_zero_max() -> void:
	check(not HudCore.is_low_hp(0, 0), "max_hp 0 never reports low (no divide-by-zero)")
