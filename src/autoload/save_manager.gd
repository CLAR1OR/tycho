extends Node
## SaveManager autoload — slots + profile on disk (architecture-schemas.md §1).
##
## Thin by rule: shapes/defaults/migrations live in SaveData (pure, tested); this
## node only does file IO and hands state to/collects state from the live systems.
##
## Files: user://saves/save_slot_<n>.json (one per slot) + user://saves/profile.json
## (settings + achievements — shared across slots, survives slot deletion).
##
## v1 save points (locked design): save on town return + autosave between floors.
## Callers do that; this class just exposes create/load/save/delete.
##
## Wiring new systems in: add one line each to _collect_from_systems() and
## _apply_to_systems(). Keep the save sections per-pillar (decoupling rule).

const SAVE_DIR := "user://saves"

## The active slot's full state dict (schema §1). -1 / empty until a slot is loaded.
var current_slot: int = -1
var state: Dictionary = {}
var profile: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	load_profile()


# --- Slots --------------------------------------------------------------------

func slot_path(slot: int) -> String:
	return "%s/save_slot_%d.json" % [SAVE_DIR, slot]


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Slot metadata for the slot-select screen WITHOUT applying anything to live
## systems. Returns [{ "slot": int, "meta": Dictionary, "checkpoint_floor": int }]
## sorted by slot (checkpoint_floor 0 = not mid-run, else the floor a resume enters).
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not (file.begins_with("save_slot_") and file.ends_with(".json")):
			continue
		var slot := int(file.trim_prefix("save_slot_").trim_suffix(".json"))
		var data := _read_json(SAVE_DIR + "/" + file)
		if data.is_empty():
			continue  # unreadable/corrupt — _read_json already yelled
		var migrated := SaveData.migrate_slot(data)
		var cp_floor := 0
		if migrated["checkpoint"] is Dictionary:
			cp_floor = int(((migrated["checkpoint"] as Dictionary).get("run", {}) as Dictionary).get("floor", 0))
		out.append({"slot": slot, "meta": migrated["meta"], "checkpoint_floor": cp_floor})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["slot"] < b["slot"])
	return out


## Start a fresh slot (overwrites an existing file at that number) and make it live.
func create_slot(slot: int, slot_name: String) -> void:
	state = SaveData.default_slot(slot_name, _now())
	current_slot = slot
	_apply_to_systems()
	_write_json(slot_path(slot), state)
	EventBus.save_loaded.emit(slot)


## Load a slot from disk, migrate it, and hand its state to the live systems.
func load_slot(slot: int) -> bool:
	var data := _read_json(slot_path(slot))
	if data.is_empty():
		return false
	var version := int(data.get("save_version", 1))
	if version > SaveData.SAVE_VERSION:
		push_error("SaveManager: slot %d is from a NEWER game version (save_version %d > %d) — refusing to load" % [slot, version, SaveData.SAVE_VERSION])
		return false
	state = SaveData.migrate_slot(data)
	current_slot = slot
	_apply_to_systems()
	EventBus.save_loaded.emit(slot)
	return true


## Collect live-system state into the active slot and write it out.
func save_current() -> bool:
	if current_slot < 0:
		push_error("SaveManager: save_current() with no slot loaded")
		return false
	_collect_from_systems()
	state["meta"]["updated_at"] = _now()
	return _write_json(slot_path(current_slot), state)


func delete_slot(slot: int) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(slot_path(slot))
	if slot == current_slot:
		current_slot = -1
		state = {}


# --- Profile (settings + achievements; shared across slots) --------------------

func profile_path() -> String:
	return SAVE_DIR + "/profile.json"


func load_profile() -> void:
	var data := _read_json(profile_path())
	profile = SaveData.migrate_profile(data)  # {} in, defaults out — first launch works


func save_profile() -> bool:
	return _write_json(profile_path(), profile)


# --- System wiring (one line per system; grows with the project) ----------------

func _collect_from_systems() -> void:
	state["ledger"] = Ledger.to_dict()


func _apply_to_systems() -> void:
	Ledger.reset(state["ledger"])


# --- IO helpers -----------------------------------------------------------------

func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("SaveManager: cannot open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("SaveManager: %s is not valid JSON — ignoring it" % path)
		return {}
	return parsed


func _write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true
