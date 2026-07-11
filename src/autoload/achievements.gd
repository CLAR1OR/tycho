extends Node
## Achievements autoload — the generic EventBus-driven achievement evaluator
## (architecture-schemas.md §5). Thin by rule: it subscribes to the gameplay signals,
## translates each signal's args into a payload dict (THE single home of that
## contract — AchievementCore.KNOWN_PAYLOADS mirrors it and the unit suite asserts
## every event name is a real EventBus signal), delegates the matching/progress math
## to pure AchievementCore, and writes the result back through SaveManager's existing
## profile API. It holds no achievement state of its own — unlocks/progress live in
## profile.json (PROFILE-level: shared across slots, survive slot deletion — locked
## decision, schemas §1).
##
## RETURN-A-NEW-DICT: AchievementCore.apply_event returns a fresh achievements dict
## (the TownCore/TechCore convention — see its header), so this autoload REASSIGNS
## SaveManager.profile["achievements"] on every change and nothing may hold that dict
## across a call. The profile is saved ONLY when something changed (resource_changed
## fires constantly; an inert event must never cost a disk write).
##
## Signal -> payload mapping (the contract):
##   run_started(n)                      -> {run_number}
##   run_ended(victory, floor, stats)    -> {victory, floor_reached, rooms_cleared}
##   death(source_id)                    -> {source_id}
##   dissolved()                         -> {}
##   boss_killed(boss_id, floor)         -> {boss_id, floor}
##   resource_changed(id, old, new, why) -> {id, old_amount, new_amount, reason}
##   tech_researched(tech_id)            -> {tech_id}
##   age_advanced(age)                   -> {age}
##   building_built(building_id, level)  -> {building_id, level}
##   dialogue_seen(dialogue_id)          -> {dialogue_id}
##   codex_shard_added(total)            -> {total}
##
## NOTE data coupling: data/achievements/codex-complete.json's `total >= 6` is coupled
## to StoryCore.CODEX_SHARDS_MAX (data can't read consts) — keep them in sync.
##
## NOTE cheats: the F2 cheat panel's simulate_run/grants emit REAL EventBus events, so
## cheats can unlock achievements. Accepted for v1 — it is a diagnostics tool for a
## single human player, and achievements carry no economy.
##
## Registered in project.godot [autoload] right after TechState: it only READS the
## story-agnostic signal payloads plus the profile, so it needs no ordering guarantee
## beyond SaveManager (which loads the profile) being up first.

## The unlock toast rides its own CanvasLayer so it shows over every scene and HUD
## (game.gd's HUD layer is 1). HUMAN: placeholder layer number.
const TOAST_LAYER := 90

var _defs: Dictionary = {}
var _toast: AchievementToast = null


func _ready() -> void:
	_defs = _load_defs()
	EventBus.run_started.connect(func(run_number: int) -> void:
		_apply("run_started", {"run_number": run_number}))
	EventBus.run_ended.connect(func(victory: bool, floor_reached: int, stats: Dictionary) -> void:
		_apply("run_ended", {"victory": victory, "floor_reached": floor_reached,
			"rooms_cleared": int(stats.get("rooms_cleared", 0))}))
	EventBus.death.connect(func(source_id: String) -> void:
		_apply("death", {"source_id": source_id}))
	EventBus.dissolved.connect(func() -> void:
		_apply("dissolved", {}))
	EventBus.boss_killed.connect(func(boss_id: String, floor_num: int) -> void:
		_apply("boss_killed", {"boss_id": boss_id, "floor": floor_num}))
	EventBus.resource_changed.connect(func(id: String, old_amount: float, new_amount: float, reason: String) -> void:
		_apply("resource_changed", {"id": id, "old_amount": old_amount,
			"new_amount": new_amount, "reason": reason}))
	EventBus.tech_researched.connect(func(tech_id: String) -> void:
		_apply("tech_researched", {"tech_id": tech_id}))
	EventBus.age_advanced.connect(func(age: int) -> void:
		_apply("age_advanced", {"age": age}))
	EventBus.building_built.connect(func(building_id: String, level: int) -> void:
		_apply("building_built", {"building_id": building_id, "level": level}))
	EventBus.dialogue_seen.connect(func(dialogue_id: String) -> void:
		_apply("dialogue_seen", {"dialogue_id": dialogue_id}))
	EventBus.codex_shard_added.connect(func(total: int) -> void:
		_apply("codex_shard_added", {"total": total}))
	# The unlock toast: autoload-owned CanvasLayer, so it works in town AND in-run.
	var layer := CanvasLayer.new()
	layer.layer = TOAST_LAYER
	add_child(layer)
	_toast = AchievementToast.new()
	layer.add_child(_toast)


## The loaded (validated) achievement defs — the achievements page reads these.
func defs() -> Dictionary:
	return _defs


## Fold one event into the profile: evaluate, reassign, save-if-changed, announce.
func _apply(event_name: String, payload: Dictionary) -> void:
	if _defs.is_empty():
		return
	var result := AchievementCore.apply_event(
		SaveManager.profile["achievements"], _defs, event_name, payload, _now())
	if not bool(result["changed"]):
		return
	SaveManager.profile["achievements"] = result["achievements"]
	SaveManager.save_profile()
	for id: String in result["unlocked"]:
		EventBus.achievement_unlocked.emit(id)
		if _toast != null:
			_toast.enqueue(str(_defs[id]["name"]), str(_defs[id]["icon"]))


## Load data/achievements/ through DataLoader (shape), then run AchievementCore.validate
## (sequencing: known event, known where fields, sane count) — invalid defs are skipped
## LOUDLY, like every data domain.
func _load_defs() -> Dictionary:
	var out := {}
	var loaded := DataLoader.load_domain("achievements")
	for id: String in loaded:
		var errors := AchievementCore.validate(loaded[id])
		if errors.is_empty():
			out[id] = loaded[id]
		else:
			for e in errors:
				push_error("Achievements: " + e)
	return out


func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)
