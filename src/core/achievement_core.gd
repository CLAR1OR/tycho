extends RefCounted
class_name AchievementCore
## Pure achievement-evaluation logic (architecture-schemas.md §5): the generic
## EventBus-driven evaluator over data/achievements/ defs. No engine singletons, no
## EventBus, no clock — the timestamp is passed in — so every path unit-tests headless.
## The Achievements autoload owns the subscriptions, the profile write, and the
## achievement_unlocked emits; this class owns only the matching + progress math.
##
## RETURN-A-NEW-DICT by design (the TownCore/TechCore convention, NOT StoryCore's
## in-place style): apply_event returns a fresh achievements dict and the caller
## reassigns SaveManager.profile["achievements"]. Chosen because (a) nothing holds a
## live ref to the profile's achievements dict across calls — the page and the toast
## read fresh through the helpers below, so StoryCore's stale-ref hazard doesn't
## apply — and (b) a side-effect-free apply_event keeps the frequent resource_changed
## path trivially testable (in == out object identity is never relied on).
##
## Def trigger shape (data/achievements/<id>.json, schema in DataLoader):
##   {"event": String, "where": {field: scalar | {"gte": N}}, "count": int (default 1)}
## `where` semantics: every key names a field of the event's payload; a scalar matches
## by equality, a {"gte": N} object matches numerically payload[field] >= N. count > 1
## makes it a progress achievement: it counts matching events across the profile's
## lifetime and unlocks when progress reaches count.
##
## Profile entry shape (profile.json "achievements", schema §1):
##   id -> {"progress": int} while locked, + {"unlocked_at": iso} once unlocked.

## The event names the evaluator understands, with each event's payload fields. This
## mirrors the Achievements autoload's signal->payload mapping (the single home of that
## contract — achievements.gd); the unit suite asserts every name here is a real
## EventBus signal so a bus rename fails loudly.
const KNOWN_PAYLOADS: Dictionary = {
	"run_started": ["run_number"],
	"run_ended": ["victory", "floor_reached", "rooms_cleared"],
	"death": ["source_id"],
	"dissolved": [],
	"boss_killed": ["boss_id", "floor"],
	"resource_changed": ["id", "old_amount", "new_amount", "reason"],
	"tech_researched": ["tech_id"],
	"age_advanced": ["age"],
	"building_built": ["building_id", "level"],
	"dialogue_seen": ["dialogue_id"],
	"codex_shard_added": ["total"],
}


## True when `trigger` fires on this event: the event name matches AND every `where`
## clause holds against the payload. A clause on a field the payload lacks never
## matches (defensive — validate() catches authored typos loudly at load).
static func matches(trigger: Dictionary, event_name: String, payload: Dictionary) -> bool:
	if str(trigger.get("event", "")) != event_name:
		return false
	var where: Dictionary = trigger.get("where", {})
	for field: String in where:
		if not payload.has(field):
			return false
		if not _clause_holds(where[field], payload[field]):
			return false
	return true


## One where clause: a {"gte": N} object compares numerically; any scalar compares by
## equality (numbers numerically — JSON parses ints as float, signals send real ints).
static func _clause_holds(want: Variant, got: Variant) -> bool:
	if want is Dictionary:
		var gte: Variant = (want as Dictionary).get("gte")
		return (got is int or got is float) and (gte is int or gte is float) \
			and float(got) >= float(gte)
	if (want is int or want is float) and (got is int or got is float):
		return is_equal_approx(float(want), float(got))
	return want == got


## Fold one event into the profile's achievements dict. Returns
##   {"achievements": Dictionary (a NEW dict), "unlocked": Array[String], "changed": bool}
## Already-unlocked defs are inert; a locked def whose trigger matches gains one
## progress; reaching `count` unlocks it, stamping unlocked_at = now_iso. `changed` is
## true iff any progress or unlock happened — the autoload only saves the profile then
## (resource_changed fires constantly; an untouched event must not cost a disk write).
static func apply_event(achievements: Dictionary, defs: Dictionary, event_name: String,
		payload: Dictionary, now_iso: String) -> Dictionary:
	var out := achievements.duplicate(true)
	var unlocked: Array[String] = []
	var changed := false
	for id: String in defs:
		var entry: Dictionary = out.get(id, {})
		if str(entry.get("unlocked_at", "")) != "":
			continue  # already unlocked — inert forever
		if not matches(defs[id].get("trigger", {}), event_name, payload):
			continue
		var progress := int(entry.get("progress", 0)) + 1
		entry["progress"] = progress
		if progress >= trigger_count(defs[id]):
			entry["unlocked_at"] = now_iso
			unlocked.append(id)
		out[id] = entry
		changed = true
	return {"achievements": out, "unlocked": unlocked, "changed": changed}


## Sequencing checks the shape schema (DataLoader) can't see. Returns error strings;
## callers push_error them — loud, never silent (a broken def is skipped, like every
## data domain).
static func validate(def: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var id := str(def.get("id", "?"))
	var trigger: Variant = def.get("trigger", {})
	if not (trigger is Dictionary):
		errors.append("achievement %s: trigger must be an object" % id)
		return errors
	var event := str((trigger as Dictionary).get("event", ""))
	if not KNOWN_PAYLOADS.has(event):
		errors.append("achievement %s: unknown trigger.event \"%s\" (known: %s)"
			% [id, event, KNOWN_PAYLOADS.keys()])
		return errors
	var fields: Array = KNOWN_PAYLOADS[event]
	var where: Variant = (trigger as Dictionary).get("where", {})
	if not (where is Dictionary):
		errors.append("achievement %s: trigger.where must be an object" % id)
	else:
		for field: Variant in (where as Dictionary):
			if not fields.has(field):
				errors.append("achievement %s: where field \"%s\" is not in %s's payload %s"
					% [id, field, event, fields])
			var clause: Variant = (where as Dictionary)[field]
			if clause is Dictionary:
				var cd := clause as Dictionary
				if cd.size() != 1 or not cd.has("gte") or not (cd["gte"] is int or cd["gte"] is float):
					errors.append("achievement %s: where.%s object must be exactly {\"gte\": number}"
						% [id, field])
			elif not (clause is String or clause is bool or clause is int or clause is float):
				errors.append("achievement %s: where.%s must be a scalar or {\"gte\": N}" % [id, field])
	var count: Variant = (trigger as Dictionary).get("count", 1)
	if not (count is int or (count is float and is_equal_approx(count, roundf(count)))) or int(count) < 1:
		errors.append("achievement %s: trigger.count must be an int >= 1 (got %s)" % [id, str(count)])
	return errors


## The def's unlock threshold (trigger.count, default 1). JSON numbers parse as float.
static func trigger_count(def: Dictionary) -> int:
	return maxi(1, int((def.get("trigger", {}) as Dictionary).get("count", 1)))


# --- UI helpers ----------------------------------------------------------------------

static func is_unlocked(achievements: Dictionary, id: String) -> bool:
	return str((achievements.get(id, {}) as Dictionary).get("unlocked_at", "")) != ""


static func progress_of(achievements: Dictionary, id: String) -> int:
	return int((achievements.get(id, {}) as Dictionary).get("progress", 0))
