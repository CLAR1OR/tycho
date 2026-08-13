extends "res://tests/test_suite.gd"
## Tests EmberMenuCore (src/core/ember_menu_core.gd) — the pure layout + formatting rules
## the Ember menu screens share (design/ui-hud.md § "Ember menu vocabulary"). All pure,
## headless. The layout tests assert RELATIONSHIPS (order, containment, symmetry), never
## exact pixels — every constant in the core is a human dial, and a test that pins a
## placeholder to a number would just break the moment the human dials it.

const BASE := Vector2(1280, 720)


# --- Catalogue layout ----------------------------------------------------------

func test_catalogue_columns_run_left_to_right_without_overlap() -> void:
	var l := EmberMenuCore.catalogue(BASE)
	var rail: Rect2 = l["rail"]
	var list: Rect2 = l["list"]
	var hero: Rect2 = l["hero"]
	var dock: Rect2 = l["dock"]
	check(rail.end.x <= list.position.x, "rail sits left of the list")
	check(list.end.x <= hero.position.x, "list sits left of the hero stage")
	check(hero.end.x <= dock.position.x, "hero stage sits left of the dock")


func test_catalogue_columns_stay_inside_the_screen() -> void:
	var l := EmberMenuCore.catalogue(BASE)
	for key: String in ["rail", "list", "hero", "dock", "content"]:
		var r: Rect2 = l[key]
		check(r.position.x >= 0.0, "%s starts on screen" % key)
		check(r.end.x <= BASE.x, "%s ends on screen" % key)
		check(r.end.y <= BASE.y, "%s stays above the bottom edge" % key)


func test_catalogue_columns_share_the_content_band() -> void:
	var l := EmberMenuCore.catalogue(BASE)
	var content: Rect2 = l["content"]
	for key: String in ["rail", "list", "hero", "dock"]:
		var r: Rect2 = l[key]
		check_eq(r.position.y, content.position.y, "%s starts at the content top" % key)
		check_eq(r.size.y, content.size.y, "%s is the content band tall" % key)


func test_catalogue_bands_are_ordered_top_to_bottom() -> void:
	var l := EmberMenuCore.catalogue(BASE)
	var title: Rect2 = l["title"]
	var subtitle: Rect2 = l["subtitle"]
	var content: Rect2 = l["content"]
	var footer: Rect2 = l["footer"]
	check(title.position.y < subtitle.position.y, "subtitle sits under the title")
	check(subtitle.position.y < content.position.y, "content starts under the subtitle")
	check(content.end.y <= footer.position.y, "the footer clears the content band")
	check(footer.position.y <= BASE.y, "the footer is on screen")


func test_catalogue_drops_the_rail_on_a_narrow_screen() -> void:
	var narrow := EmberMenuCore.catalogue(Vector2(800, 600))
	var rail: Rect2 = narrow["rail"]
	check_eq(rail.size.x, 0.0, "below RAIL_MIN_W_PX the rail is dropped, not squeezed")
	var list: Rect2 = narrow["list"]
	check(list.position.x < list.end.x, "the list still has width without the rail")


func test_catalogue_widens_with_the_screen() -> void:
	var small: Rect2 = EmberMenuCore.catalogue(BASE)["dock"]
	var big: Rect2 = EmberMenuCore.catalogue(Vector2(1920, 1080))["dock"]
	check(big.size.x > small.size.x, "the dock grows with the viewport")


# --- Column layout -------------------------------------------------------------

func test_column_is_centred() -> void:
	var l := EmberMenuCore.column(BASE)
	var col: Rect2 = l["column"]
	var left_gap := col.position.x
	var right_gap := BASE.x - col.end.x
	check(absf(left_gap - right_gap) < 0.01, "the single column is centred")


func test_column_never_exceeds_the_content_band() -> void:
	var l := EmberMenuCore.column(Vector2(500, 600), 900.0)
	var col: Rect2 = l["column"]
	var content: Rect2 = l["content"]
	check(col.size.x <= content.size.x, "a too-wide column is clamped to the content band")


func test_column_and_catalogue_share_their_bands() -> void:
	var cat := EmberMenuCore.catalogue(BASE)
	var col := EmberMenuCore.column(BASE)
	for key: String in ["title", "subtitle", "footer", "content"]:
		check_eq(col[key], cat[key],
			"%s band is identical in both layouts (that is what makes them one language)" % key)


# --- Stacking ------------------------------------------------------------------

func test_stack_lays_rows_down_the_column() -> void:
	var col := Rect2(10, 20, 300, 400)
	var rows := EmberMenuCore.stack(col, 3, 50.0, 10.0)
	check_eq(rows.size(), 3, "one rect per row")
	check_eq(rows[0], Rect2(10, 20, 300, 50), "first row sits at the column top")
	check_eq(rows[1].position.y, 80.0, "second row clears the first plus the gap")
	check_eq(rows[2].position.y, 140.0, "rows advance by row_h + gap")


func test_stack_of_zero_is_empty() -> void:
	check_eq(EmberMenuCore.stack(Rect2(0, 0, 100, 100), 0, 10.0, 2.0).size(), 0,
		"no rows, no rects")
	check_eq(EmberMenuCore.stack(Rect2(0, 0, 100, 100), -3, 10.0, 2.0).size(), 0,
		"a negative count never crashes")


func test_rows_that_fit_counts_the_last_row_without_a_trailing_gap() -> void:
	# 3 rows of 50 + 2 gaps of 10 = 170; a 170-tall column fits exactly 3.
	check_eq(EmberMenuCore.rows_that_fit(Rect2(0, 0, 100, 170), 50.0, 10.0), 3,
		"the trailing gap is not required")
	check_eq(EmberMenuCore.rows_that_fit(Rect2(0, 0, 100, 169), 50.0, 10.0), 2,
		"one pixel short and the third row does not fit")
	check_eq(EmberMenuCore.rows_that_fit(Rect2(0, 0, 100, 170), 0.0, 10.0), 0,
		"a zero-height row never divides by zero")


# --- Stat deltas ---------------------------------------------------------------

func test_stat_delta_reports_an_improvement() -> void:
	var d := EmberMenuCore.stat_delta(38, 44)
	check_eq(d["from"], "38", "from value")
	check_eq(d["to"], "44", "to value")
	check(bool(d["changed"]), "38 -> 44 is a change")
	check(bool(d["improved"]), "44 is better than 38")


func test_stat_delta_reports_no_change() -> void:
	var d := EmberMenuCore.stat_delta(12, 12)
	check(not bool(d["changed"]), "an unchanged stat draws no arrow")
	check(not bool(d["improved"]), "unchanged is not an improvement")


func test_stat_delta_reports_a_downgrade() -> void:
	var d := EmberMenuCore.stat_delta(1.2, 0.8, "x")
	check(bool(d["changed"]), "1.2 -> 0.8 is a change")
	check(not bool(d["improved"]), "a drop is not an improvement")
	check_eq(d["to"], "0.80", "the x unit keeps two decimals")


func test_format_stat_units() -> void:
	check_eq(EmberMenuCore.format_stat(38), "38", "plain whole number prints bare")
	check_eq(EmberMenuCore.format_stat(120, "%"), "120%", "percent unit")
	check_eq(EmberMenuCore.format_stat(0.8, "x"), "0.80", "x unit keeps two decimals")
	check_eq(EmberMenuCore.format_stat(1.5), "1.5",
		"a fractional plain value keeps a decimal instead of rounding away")
	check_eq(EmberMenuCore.format_stat(14.999, "%"), "15%", "percent rounds to whole")


# --- Cost rows -----------------------------------------------------------------

func test_cost_rows_affordable() -> void:
	var r := EmberMenuCore.cost_rows({"gold": 80, "stone": 20}, {"gold": 128, "stone": 35})
	check(bool(r["affordable"]), "both costs are covered")
	var rows: Array = r["rows"]
	check_eq(rows.size(), 2, "one row per cost")
	check_eq(rows[0]["id"], "gold", "row order follows the def's key order")
	check_eq(rows[0]["have"], 128.0, "carries what the Ledger holds")


func test_cost_rows_one_short_blocks_the_action() -> void:
	var r := EmberMenuCore.cost_rows({"gold": 80, "stone": 40}, {"gold": 128, "stone": 35})
	check(not bool(r["affordable"]), "one short resource blocks the whole action")
	var rows: Array = r["rows"]
	check(bool(rows[0]["ok"]), "gold is covered")
	check(not bool(rows[1]["ok"]), "stone is not")


func test_cost_rows_treats_a_missing_resource_as_zero() -> void:
	var r := EmberMenuCore.cost_rows({"resonance-ore": 5}, {})
	check(not bool(r["affordable"]), "an empty Ledger affords nothing")
	check_eq(r["rows"][0]["have"], 0.0, "a resource never held reads as 0, not null")


func test_cost_rows_exact_amount_is_affordable() -> void:
	var r := EmberMenuCore.cost_rows({"gold": 40}, {"gold": 40})
	check(bool(r["affordable"]), "having exactly the cost is enough")


func test_no_cost_is_affordable() -> void:
	var r := EmberMenuCore.cost_rows({}, {})
	check(bool(r["affordable"]), "a free action is always affordable")
	check_eq(r["rows"].size(), 0, "and draws no cost rows")


# --- Pip tracks ----------------------------------------------------------------

func test_pip_states_mid_track() -> void:
	check_eq(EmberMenuCore.pip_states(2, 5),
		["filled", "filled", "next", "rest", "rest"] as Array[String],
		"two owned, one buyable, two beyond")


func test_pip_states_unbuilt() -> void:
	check_eq(EmberMenuCore.pip_states(0, 3), ["next", "rest", "rest"] as Array[String],
		"an unbuilt track advertises its first level")


func test_pip_states_maxed_is_all_filled() -> void:
	check_eq(EmberMenuCore.pip_states(5, 5),
		["filled", "filled", "filled", "filled", "filled"] as Array[String],
		"a finished track stops advertising a next step")


func test_pip_states_degenerate_track() -> void:
	check_eq(EmberMenuCore.pip_states(0, 0).size(), 0, "a zero-level track draws nothing")


func test_is_maxed_matches_the_pip_track() -> void:
	check(EmberMenuCore.is_maxed(5, 5), "level == max is maxed")
	check(EmberMenuCore.is_maxed(6, 5), "an over-levelled save still reads as maxed")
	check(not EmberMenuCore.is_maxed(4, 5), "one short is not maxed")
	check(not EmberMenuCore.is_maxed(0, 0), "a track with no levels is never maxed")


# --- Truncation ----------------------------------------------------------------

func test_truncate_leaves_short_strings_alone() -> void:
	check_eq(EmberMenuCore.truncate("Sword", 10), "Sword", "it fits, so nothing happens")


func test_truncate_adds_an_ellipsis() -> void:
	check_eq(EmberMenuCore.truncate("Bear-Crown Hammer", 10), "Bear-Crow…",
		"the ellipsis replaces the last kept character")


func test_truncate_does_not_leave_a_dangling_space() -> void:
	check_eq(EmberMenuCore.truncate("Sophia's Desk", 9), "Sophia's…",
		"a trailing space before the ellipsis is trimmed")


func test_truncate_degenerate_width() -> void:
	check_eq(EmberMenuCore.truncate("anything", 0), "", "no room means no text")
