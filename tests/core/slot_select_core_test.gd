extends "res://tests/test_suite.gd"
## Tests SlotSelectCore (src/core/slot_select_core.gd) — the pure slot-select helpers:
## playtime formatting, the mid-run badge string, and the meta-line parts/shape. All
## pure, headless.


func test_fmt_playtime_under_an_hour() -> void:
	check_eq(SlotSelectCore.fmt_playtime(0.0), "0m", "zero → 0m")
	check_eq(SlotSelectCore.fmt_playtime(41.0 * 60.0), "41m", "41 minutes → 41m")
	check_eq(SlotSelectCore.fmt_playtime(59.0 * 60.0 + 59.0), "59m", "just under an hour → 59m")


func test_fmt_playtime_over_an_hour() -> void:
	check_eq(SlotSelectCore.fmt_playtime(3.0 * 3600.0 + 22.0 * 60.0), "3h 22m", "3h22m")
	check_eq(SlotSelectCore.fmt_playtime(60.0 * 60.0), "1h 00m", "exactly an hour → 1h 00m (zero-padded)")


func test_badge_text() -> void:
	check_eq(SlotSelectCore.badge_text(0), "", "not mid-run → empty badge")
	check_eq(SlotSelectCore.badge_text(2), "⚔ FLOOR 2", "mid-run → the shortened FLOOR badge")


func test_meta_parts_and_line() -> void:
	var meta := {"age": 1, "runs": 14, "playtime_s": 3.0 * 3600.0 + 22.0 * 60.0,
		"updated_at": "2026-07-08T14:30:22"}
	var parts := SlotSelectCore.meta_parts(meta)
	check_eq(str(parts["prefix"]), "AGE 1 · ", "prefix carries the age")
	check_eq(str(parts["runs"]), "14", "runs is its own part (for the colour split)")
	check_eq(str(parts["suffix"]), " RUNS · 3h 22m · saved 2026-07-08",
		"suffix carries playtime + the day-trimmed saved date")
	check_eq(SlotSelectCore.meta_line(meta), "AGE 1 · 14 RUNS · 3h 22m · saved 2026-07-08",
		"the flat line is the parts concatenated")
