extends RefCounted
class_name SaveData
## Pure save-schema logic (architecture-schemas.md §1): canonical default shapes,
## the version-migration chain, and the defaults-merge that guarantees "never read
## fields without defaults". No file IO, no engine singletons, no clock — timestamps
## are passed in — so every path here unit-tests headless. SaveManager owns files.

const SAVE_VERSION := 1
const PROFILE_VERSION := 1


## The canonical empty slot. Every section from the schema exists from day one —
## including the reserved (empty) Act II/III pillar keys, so later acts extend
## instead of migrating.
static func default_slot(slot_name: String, now_iso: String) -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"meta": {
			"name": slot_name,
			"created_at": now_iso,
			"updated_at": now_iso,
			"playtime_s": 0.0,
			"age": 1,
			"act": 1,
			"runs": 0,
		},
		"story": {
			"flags": {},
			# dissolves: full-clear returns via the codex artifact (2026-07-07) — separate
			# from deaths (combat only). defaults-merge fills it for old saves.
			"counters": {"runs": 0, "deaths": 0, "dissolves": 0, "boss_kills": 0, "full_clears": 0},
			"seen": [],
			"talked_to": {},
			"dialogue_last": {},
			"arc_last": {},
		},
		# quiz_locked {id: true}: a wrong quiz answer locks that node's quiz until one
		# more run passes (cleared on run_ended; 2026-07-06). defaults-merge fills it
		# for old saves.
		"tech": {"researched": [], "in_progress": {}, "auto_solve_counters": {}, "quiz_locked": {}, "active": ""},
		"ledger": {},
		# well_fed: last day-tick Food-upkeep status (design/food-upkeep.md). false
		# until the town has ever ticked with food covering upkeep; defaults-merge
		# fills it for old saves.
		# market_deal_done_day: the last day a caravan deal was accepted (one per day,
		# town-economy.md 2026-07-10); -1 = never. defaults-merge fills old saves.
		"town": {"id": "home", "name": "Home", "age": 1, "buildings": [], "map_pos": null,
			"well_fed": false, "market_deal_done_day": -1},
		"combat": {
			"current_weapon": "sword",
			"weapons": {},
			"etchings": {"slots": {"rmb": "", "q": "", "r": ""}, "unlocked": {}},
			"attunements": {},
			"assist_mode": {"enabled": false, "stacks": 0},
		},
		"codex": {"shards": 0},
		# Per-floor autosave (PRD §7.13: no mid-run saves — quit mid-run resumes at
		# floor start). null = not in a run. When set: {run, run_number, echoes,
		# player_health} snapshotted as a floor's first room loads; cleared on run end.
		# Echoes here never outlive their run, so the in-run-only lock holds.
		"checkpoint": null,
		"pillars": {"strategy": {}, "space": {}},  # EMPTY in v1, reserved for Acts II/III
	}


static func default_profile() -> Dictionary:
	return {
		"profile_version": PROFILE_VERSION,
		# Profile-level (survive slot deletion): audio, controls, accessibility.
		# Audio volumes are LINEAR 0..1 (Music autoload converts to bus dB); the
		# settings UI can lag (design/audio.md) — data-only for now. Controls +
		# accessibility land with their screens; defaults-merge fills them for
		# existing profiles that predate a key. window_mode ("windowed"/"fullscreen") is
		# read via SettingsCore.window_mode (any other value → windowed) — SET1, 2026-07-09.
		"settings": {"music_volume": 1.0, "sfx_volume": 1.0, "ui_volume": 1.0, "window_mode": "windowed"},
		"achievements": {},   # id -> {unlocked_at, progress}
	}


## Bring a loaded slot dict up to the current version, then fill any missing keys
## with defaults (so code never reads an absent field). Unknown extra keys are kept
## verbatim — forward compatibility for the pillar sections. Returns a new dict.
static func migrate_slot(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var version := int(out.get("save_version", 1))
	while version < SAVE_VERSION:
		out = _apply_slot_migration(version, out)
		version = int(out.get("save_version", version + 1))
	return merge_defaults(default_slot("", ""), out)


static func migrate_profile(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	# No profile migrations exist yet; chain mirrors migrate_slot when they do.
	return merge_defaults(default_profile(), out)


## One pure migration step vN → vN+1. Grows a match arm per version bump; each arm
## MUST set "save_version" to its target or the chain aborts (defensive: bail loudly
## rather than loop).
static func _apply_slot_migration(from_version: int, data: Dictionary) -> Dictionary:
	match from_version:
		# Example shape for the future:
		# 1:
		#	data["combat"]["new_field"] = ...
		#	data["save_version"] = 2
		_:
			push_error("SaveData: no migration from save_version %d — treating as current" % from_version)
			data["save_version"] = SAVE_VERSION
	return data


## Recursive "fill the gaps" merge: every key in `defaults` is guaranteed present in
## the result; existing values in `data` always win; keys only in `data` survive.
static func merge_defaults(defaults: Dictionary, data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for key: Variant in defaults:
		if not out.has(key):
			out[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary or defaults[key] is Array else defaults[key]
		elif defaults[key] is Dictionary and out[key] is Dictionary:
			out[key] = merge_defaults(defaults[key], out[key])
	return out
