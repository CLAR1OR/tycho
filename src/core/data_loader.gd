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
