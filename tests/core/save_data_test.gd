extends "res://tests/test_suite.gd"
## Unit tests for SaveData (src/core/save_data.gd) — schema defaults + migrations.


func test_default_slot_has_every_section() -> void:
	var s := SaveData.default_slot("Slot 1", "2026-07-01T12:00:00")
	for section in ["save_version", "meta", "story", "tech", "ledger", "town", "combat", "codex", "checkpoint", "pillars"]:
		check(s.has(section), "default slot has section \"%s\"" % section)
	check_eq(s["save_version"], SaveData.SAVE_VERSION, "fresh slot is current version")
	check_eq(s["meta"]["name"], "Slot 1", "slot name lands in meta")
	check(s["pillars"].has("strategy") and s["pillars"].has("space"), "Act II/III pillar keys reserved")
	check_eq(s["story"]["counters"]["boss_kills"], 0, "counters start at zero")


func test_merge_defaults_fills_gaps_keeps_values() -> void:
	var defaults := {"a": 1, "nested": {"x": 10, "y": 20}, "list": [1, 2]}
	var data := {"nested": {"x": 99}, "extra": "kept"}
	var out := SaveData.merge_defaults(defaults, data)
	check_eq(out["a"], 1, "missing top-level key filled from defaults")
	check_eq(out["nested"]["x"], 99, "existing value wins over default")
	check_eq(out["nested"]["y"], 20, "missing nested key filled")
	check_eq(out["extra"], "kept", "unknown keys survive (forward compat)")
	check_eq(out["list"], [1, 2], "missing arrays filled")


func test_merge_defaults_copies_do_not_alias() -> void:
	var defaults := {"nested": {"x": 1}}
	var out := SaveData.merge_defaults(defaults, {})
	out["nested"]["x"] = 42
	check_eq(defaults["nested"]["x"], 1, "merged defaults are deep copies, not aliases")


func test_migrate_slot_repairs_partial_save() -> void:
	# Simulate an old/damaged save: right version but missing whole sections.
	var damaged := {"save_version": 1, "meta": {"name": "Old"}, "ledger": {"gold": 7}}
	var out := SaveData.migrate_slot(damaged)
	check_eq(out["meta"]["name"], "Old", "existing values preserved")
	check_eq(float(out["ledger"]["gold"]), 7.0, "ledger contents preserved")
	check(out.has("combat"), "missing sections restored from defaults")
	check_eq(out["combat"]["assist_mode"]["enabled"], false, "nested defaults restored")


func test_migrate_slot_handles_unknown_old_version() -> void:
	# A version we have no migration for must not loop or crash — it gets defaults.
	var ancient := {"save_version": 0, "meta": {"name": "Ancient"}}
	var out := SaveData.migrate_slot(ancient)
	check_eq(out["save_version"], SaveData.SAVE_VERSION, "chain lands on current version")
	check_eq(out["meta"]["name"], "Ancient", "data survives the forced upgrade")


func test_checkpoint_defaults_and_survival() -> void:
	var s := SaveData.default_slot("X", "2026-07-02T12:00:00")
	check_eq(s["checkpoint"], null, "fresh slot carries no checkpoint")
	# Old saves (no checkpoint key) get null; a live checkpoint survives migration.
	check_eq(SaveData.migrate_slot({"save_version": 1})["checkpoint"], null,
		"pre-checkpoint save migrates to null")
	var mid_run := {"save_version": 1,
		"checkpoint": {"run": {"floor": 2}, "run_number": 3, "echoes": ["swift-step"], "player_health": 60}}
	var out := SaveData.migrate_slot(mid_run)
	check_eq(int(out["checkpoint"]["run"]["floor"]), 2, "live checkpoint survives migration")
	check_eq(out["checkpoint"]["echoes"], ["swift-step"], "checkpoint echoes survive")


func test_default_profile_and_migrate() -> void:
	var p := SaveData.migrate_profile({})
	check_eq(p["profile_version"], SaveData.PROFILE_VERSION, "empty profile gets defaults (first launch)")
	check(p.has("settings") and p.has("achievements"), "profile sections present")
	# Audio volumes (linear 0..1) exist from day one so Music._ready can read them.
	for key in ["music_volume", "sfx_volume", "ui_volume"]:
		check_eq(float(p["settings"][key]), 1.0, "settings default %s = 1.0" % key)
	# window_mode (SET1, 2026-07-09) defaults to windowed.
	check_eq(str(p["settings"]["window_mode"]), "windowed", "settings default window_mode = windowed")


func test_profile_migrate_fills_missing_audio_settings() -> void:
	# A profile written before the audio-volume keys existed must gain them via
	# defaults-merge, while any value the player already set survives.
	var old := {"profile_version": 1, "settings": {"music_volume": 0.4}, "achievements": {}}
	var out := SaveData.migrate_profile(old)
	check_eq(float(out["settings"]["music_volume"]), 0.4, "existing volume preserved")
	check_eq(float(out["settings"]["sfx_volume"]), 1.0, "missing sfx volume filled from defaults")
	check_eq(float(out["settings"]["ui_volume"]), 1.0, "missing ui volume filled from defaults")
	# A profile predating window_mode (SET1, 2026-07-09) gains it via the nested defaults-merge.
	check_eq(str(out["settings"]["window_mode"]), "windowed", "missing window_mode filled from defaults")
