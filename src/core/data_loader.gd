extends RefCounted
class_name DataLoader
## Loads game content from data/<domain>/*.json (godot-conventions.md: content is
## JSON, code is generic — adding content must never require code). Every file is
## validated against its domain spec on load; broken entries are skipped LOUDLY
## (push_error), never returned as half-valid dicts.
##
## Conventions enforced here: one file per entity, filename == id, ids unique.
##
## New domain = add its spec to SCHEMAS below (tech, buildings, achievements, and
## dialogue land with their systems; shapes are drafted in architecture-schemas.md).

const DATA_ROOT := "res://data"

const SCHEMAS: Dictionary = {
	"resources": {  # architecture-schemas.md §2
		"id": {"type": "string", "required": true},
		"name": {"type": "string", "required": true},
		"icon": {"type": "string"},
		"role": {"type": "string", "required": true,
			"one_of": ["research", "money", "material", "energy", "military", "combat", "story"]},
		"age_active": {"type": "int", "required": true},
		"supersedes": {"type": "string", "nullable": true},
		"retired_by": {"type": "string", "nullable": true},
		"sources": {"type": "array", "array_of": "string"},
	},
	"buildings": {  # architecture-schemas.md §6
		"id": {"type": "string", "required": true},
		"name": {"type": "string", "required": true},
		"category": {"type": "string", "required": true,
			"one_of": ["production", "research", "infrastructure", "shop"]},
		"age": {"type": "int", "required": true},
		"unlocked_by": {"type": "dict", "nullable": true},
		"levels": {"type": "array", "required": true, "array_of": "dict"},  # exactly 3 per the bible
	},
	"tech": {  # architecture-schemas.md §4 — mirrors design/tech-nodes/<id>.md (the authoring source)
		"id": {"type": "string", "required": true},
		"name": {"type": "string", "required": true},
		"age": {"type": "int", "required": true},
		"tier": {"type": "string", "required": true, "one_of": ["key", "support"]},
		"cost_knowledge": {"type": "int", "required": true},
		"prereqs": {"type": "array", "array_of": "string"},
		"unlocks": {"type": "array", "required": true, "array_of": "dict"},  # typed {type, id}
		"puzzle": {"type": "dict", "required": true},  # {kind: quiz, data} | {kind: interactive, scene}
		"auto_solve_after_runs": {"type": "int"},
		"thinking_tool": {"type": "bool"},
		"explanation": {"type": "string"},  # the read-before-the-puzzle text
		"aha": {"type": "string"},          # the post-solve reveal
		# Normalized 0..1 [x, y] star position on the research constellation (R1 star
		# chart). Optional — TechChartCore.chart_pos falls back to a deterministic
		# in-band position from the id when absent, so an unpositioned node never breaks.
		"chart_pos": {"type": "array", "array_of": "float"},
	},
	"weapons": {  # PRD §7.2 — relative mods over the feel-tuned baseline kit
		"id": {"type": "string", "required": true},
		"name": {"type": "string", "required": true},
		"kind": {"type": "string", "required": true, "one_of": ["melee", "ranged"]},
		"desc": {"type": "string"},
		"mods": {"type": "array", "required": true, "array_of": "dict"},  # {stat, add, mult}
		"projectile": {"type": "dict", "nullable": true},                 # ranged: {speed}
		"flat": {"type": "dict", "required": true},  # {damage_mult_per_level, costs: [ore/level]}
	},
	"echoes": {  # PRD §7.5 — in-run upgrades; picked list lives on RunState, never saved
		"id": {"type": "string", "required": true},
		"name": {"type": "string", "required": true},
		"desc": {"type": "string", "required": true},
		"pool_weight": {"type": "float"},
		"stackable": {"type": "bool"},
		"requires": {"type": "array", "array_of": "string"},  # synergy prereq echo ids
		"mods": {"type": "array", "required": true, "array_of": "dict"},
	},
	"etchings": {  # design/etchings.md and architecture-schemas.md section 10
		"id": {"type": "string", "required": true},
		"name": {"type": "string", "required": true},
		"slot": {"type": "string", "required": true, "one_of": ["rmb", "q", "r"]},
		"principle": {"type": "string", "required": true},
		"cooldown_s": {"type": "float", "required": true},
		"granted_by": {"type": "string", "nullable": true},
		"cost_unlock_dust": {"type": "int", "required": true},
		"cost_levels_dust": {"type": "array", "required": true, "array_of": "int"},
		"behavior": {"type": "dict"},
		"levels": {"type": "array", "required": true, "array_of": "dict"},
		"weapon_synergy": {"type": "dict", "nullable": true},
		"summon_seed": {"type": "bool"},
		"desc": {"type": "string"},                          # arms panel menu copy (optional)
		"level_blurbs": {"type": "array", "array_of": "string"},  # per-level track lines (optional)
	},
	"dialogue": {  # architecture-schemas.md §7 — spec + condition vocabulary in act1-story-beats.md
		"id": {"type": "string", "required": true},
		"source": {"type": "string", "required": true,
			"one_of": ["spine", "arc", "contextual", "bark"]},
		"speakers": {"type": "array", "required": true, "array_of": "string"},  # [0] = owner
		"priority": {"type": "float"},        # tiebreak within a source rank
		"once": {"type": "bool"},             # default: true except barks
		"cooldown_runs": {"type": "int"},
		"conditions": {"type": "array", "array_of": "dict"},  # ALL must hold
		"force_play": {"type": "bool"},
		"sets_flag": {"type": "string", "nullable": true},
		"scene": {"type": "dict", "required": true},  # {kind: talk|cutscene, lines: [{who, text}]}
	},
	"floors": {  # design/run-structure.md Part 1 + architecture-schemas.md §9 (floor profile).
		# Door + peril data lives here now; the dungeon-strata env fields (palette/fog/
		# hazard/props) land LATER — adding them is purely ADDITIVE (a new spec row per
		# field + the JSON key), so this spec grows, it never reshapes.
		"id": {"type": "int", "required": true},
		"door_weights": {"type": "dict", "required": true},  # {sigil: weight} over the 5 loot sigils
		"peril_chance": {"type": "float", "required": true},  # per-door elite-modifier probability [0,1]
	},
	"ages": {  # architecture-schemas.md §3
		"id": {"type": "int", "required": true},
		"name": {"type": "string", "required": true},
		"entered_by": {"type": "string", "required": true},
		"town_skin": {"type": "string"},
		"retires_resources": {"type": "array", "array_of": "string"},
		"music": {"type": "string"},
		"palette": {"type": "string"},
	},
}


# The SFX map (design/audio.md) is deliberately ONE file mapping id -> params —
# a sound entry has no life of its own, and hand-balancing a mix wants one page.
const SFX_MAP_PATH := "res://data/audio/sfx-map.json"
const SFX_SPEC: Dictionary = {
	"file": {"type": "string", "required": true},        # res:// path to the stream
	"volume_db": {"type": "float"},                      # placeholder mix values
	"pitch_jitter": {"type": "float"},                   # ± fraction, anti-repetition
	"bus": {"type": "string", "one_of": ["Music", "SFX", "UI"]},  # default SFX
}


## Load + validate data/audio/sfx-map.json: {id: {file, volume_db, pitch_jitter,
## bus}}. Invalid entries are skipped LOUDLY, like load_domain.
static func load_sfx_map() -> Dictionary:
	return _load_single_file_map(SFX_MAP_PATH, SFX_SPEC)


# The music map (design/audio.md § Music) is ONE file like the SFX map — the same
# deliberate exception to one-file-per-entity (a track entry has no life of its
# own; a soundtrack wants one page). id -> {file, volume_db}.
const MUSIC_MAP_PATH := "res://data/audio/music-map.json"
const MUSIC_SPEC: Dictionary = {
	"file": {"type": "string", "required": true},  # res:// path to the .ogg loop
	"volume_db": {"type": "float"},                # placeholder mix / fade ceiling
}


## Load + validate data/audio/music-map.json: {id: {file, volume_db}}. Invalid
## entries are skipped LOUDLY, like the SFX map.
static func load_music_map() -> Dictionary:
	return _load_single_file_map(MUSIC_MAP_PATH, MUSIC_SPEC)


## Shared reader for the single-file id->params maps (SFX, music): parse, then
## per-entry validate against `spec`; bad entries skip loudly, never half-valid.
static func _load_single_file_map(path: String, spec: Dictionary) -> Dictionary:
	var out := {}
	var parsed := _read_entry(path)
	for id: Variant in parsed:
		var where := "%s#%s" % [path, id]
		if not (parsed[id] is Dictionary):
			push_error("DataLoader: %s must be an object" % where)
			continue
		var errors := DataValidator.validate(parsed[id], spec, where)
		if not errors.is_empty():
			for e in errors:
				push_error("DataLoader: " + e)
			continue
		out[str(id)] = parsed[id]
	return out


## Load every entry of a domain: {id: entry}. Invalid files are skipped with errors.
static func load_domain(domain: String) -> Dictionary:
	var out := {}
	if not SCHEMAS.has(domain):
		push_error("DataLoader: unknown domain \"%s\" (add its spec to SCHEMAS)" % domain)
		return out
	var dir_path := "%s/%s" % [DATA_ROOT, domain]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("DataLoader: missing data directory %s" % dir_path)
		return out
	var spec: Dictionary = SCHEMAS[domain]
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path := "%s/%s" % [dir_path, file]
		var entry := _read_entry(path)
		if entry.is_empty():
			continue
		var errors := DataValidator.validate(entry, spec, path)
		# One file per entity, filename == id. JSON parses numbers as float, so a
		# whole-valued id (ages) must normalize to int before str(), or "1" != "1.0".
		var raw_id: Variant = entry.get("id", "")
		if raw_id is float and is_equal_approx(raw_id, roundf(raw_id)):
			raw_id = int(raw_id)
		var id := str(raw_id)
		if id != file.trim_suffix(".json"):
			errors.append("%s: filename must equal id \"%s\"" % [path, id])
		if out.has(id):
			errors.append("%s: duplicate id \"%s\"" % [path, id])
		if not errors.is_empty():
			for e in errors:
				push_error("DataLoader: " + e)
			continue
		out[id] = entry
	return out


static func _read_entry(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DataLoader: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("DataLoader: %s is not a valid JSON object" % path)
		return {}
	return parsed
