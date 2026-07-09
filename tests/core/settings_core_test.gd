extends "res://tests/test_suite.gd"
## Unit tests for SettingsCore (src/core/settings_core.gd) — the settings screen's pure math:
## display rounding/clamp, notch fill, nudge bounds, and the window-mode fallback.


func test_volume_rows_shape() -> void:
	check_eq(SettingsCore.VOLUME_ROWS.size(), 3, "three volume rows")
	# Keys must match the shipped profile defaults (save_data.gd).
	var profile := SaveData.default_profile()
	for row: Dictionary in SettingsCore.VOLUME_ROWS:
		check(profile["settings"].has(str(row["key"])),
			"row key \"%s\" exists in the profile settings" % str(row["key"]))
		check(not str(row["label"]).is_empty(), "row has a label")
	check_eq(str(SettingsCore.VOLUME_ROWS[0]["key"]), "music_volume", "music leads the rows")


func test_display_value_rounds_and_clamps() -> void:
	check_eq(SettingsCore.display_value(0.0), 0, "0.0 → 0")
	check_eq(SettingsCore.display_value(0.5), 50, "0.5 → 50")
	check_eq(SettingsCore.display_value(1.0), 100, "1.0 → 100")
	check_eq(SettingsCore.display_value(0.234), 23, "0.234 rounds to 23")
	check_eq(SettingsCore.display_value(1.7), 100, "above 1 clamps to 100")
	check_eq(SettingsCore.display_value(-0.4), 0, "below 0 clamps to 0")


func test_notches_lit() -> void:
	check_eq(SettingsCore.notches_lit(0.0, 12), 0, "0 lights no notches")
	check_eq(SettingsCore.notches_lit(1.0, 12), 12, "full lights all notches")
	check_eq(SettingsCore.notches_lit(0.5, 12), 6, "half lights half")
	check_eq(SettingsCore.notches_lit(2.0, 12), 12, "over-range clamps to full")


func test_value_from_ratio_clamps() -> void:
	check_eq(SettingsCore.value_from_ratio(0.5), 0.5, "mid ratio maps through")
	check_eq(SettingsCore.value_from_ratio(-0.2), 0.0, "negative ratio clamps to 0")
	check_eq(SettingsCore.value_from_ratio(1.3), 1.0, "over-1 ratio clamps to 1")


func test_nudge_at_bounds() -> void:
	check_eq(SettingsCore.nudge(0.5, 1), 0.5 + SettingsCore.STEP, "nudge up adds a step")
	check_eq(SettingsCore.nudge(0.5, -1), 0.5 - SettingsCore.STEP, "nudge down subtracts a step")
	check_eq(SettingsCore.nudge(1.0, 1), 1.0, "nudge up at the top stays at 1")
	check_eq(SettingsCore.nudge(0.0, -1), 0.0, "nudge down at the bottom stays at 0")


func test_window_mode_fallback() -> void:
	check_eq(SettingsCore.window_mode({"settings": {"window_mode": "fullscreen"}}), "fullscreen",
		"fullscreen reads through")
	check_eq(SettingsCore.window_mode({"settings": {"window_mode": "windowed"}}), "windowed",
		"windowed reads through")
	check_eq(SettingsCore.window_mode({"settings": {}}), "windowed",
		"missing window_mode → windowed")
	check_eq(SettingsCore.window_mode({}), "windowed", "missing settings → windowed")
	check_eq(SettingsCore.window_mode({"settings": {"window_mode": "borderless-nonsense"}}), "windowed",
		"garbage value → windowed (never crashes an old profile)")
