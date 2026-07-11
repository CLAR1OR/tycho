extends RefCounted
class_name DialogueCore
## Pure dialogue eligibility + selection (PRD §7.12; the spec and condition
## vocabulary live in design/act1-story-beats.md — that doc is the contract).
##
## Everything here is `(save_state, defs, …) -> result` over plain Dictionaries:
## no engine types, fully unit-testable. The save dict is read-only to eval/select;
## mark_shown returns a NEW story section (the caller writes it back).
##
## Selection rules (spec): each character offers their single highest-priority
## eligible item; source rank spine > arc > contextual > bark, ties broken by the
## author-set `priority` weight; `once` items never repeat; `cooldown_runs` spaces
## bark repeats and same-character arc beats; force_play scenes are picked by
## select_forced (the town enforces max 1 per visit). Dialogues are fully scripted —
## the player never chooses (locked design).

const SOURCE_RANK := {"spine": 3, "arc": 2, "contextual": 1, "bark": 0}


## The single snippet `character` offers right now, or "" if they have nothing.
static func select(defs: Dictionary, save_state: Dictionary, character: String) -> String:
	var best_id := ""
	var best_key: Array = []
	for id: String in defs:
		var def: Dictionary = defs[id]
		if owner_of(def) != character:
			continue
		if not eligible(def, save_state):
			continue
		# Sort key: source rank desc, author weight desc, id asc (determinism).
		var key: Array = [-int(SOURCE_RANK.get(str(def.get("source", "bark")), 0)),
			-float(def.get("priority", 0.0)), id]
		if best_id.is_empty() or key < best_key:
			best_id = id
			best_key = key
	return best_id


## The forced scene for this town visit, or "". Spine/cutscene beats may
## force-play (banner icon later); the CALLER guarantees max 1 per visit.
static func select_forced(defs: Dictionary, save_state: Dictionary) -> String:
	var best_id := ""
	var best_key: Array = []
	for id: String in defs:
		var def: Dictionary = defs[id]
		if not bool(def.get("force_play", false)):
			continue
		if not eligible(def, save_state):
			continue
		var key: Array = [-int(SOURCE_RANK.get(str(def.get("source", "bark")), 0)),
			-float(def.get("priority", 0.0)), id]
		if best_id.is_empty() or key < best_key:
			best_id = id
			best_key = key
	return best_id


## The floating-marker a character's talk spot should show right now (town.gd
## renders it as a Label3D over the NPC): "" none, "!" new arc/contextual content,
## "!!" a new SPINE (main-story) beat. Indicator = NEW, UNSEEN content only — barks
## (repeatable flavor) and anything already seen never light it, so it always turns
## off once the player has heard the character out. Pure; unit-tested.
static func indicator_for(defs: Dictionary, save_state: Dictionary, character: String) -> String:
	var best := select(defs, save_state, character)
	if best.is_empty():
		return ""
	var def: Dictionary = defs[best]
	if str(def.get("source", "bark")) == "bark":
		return ""  # only a repeatable bark is on offer — not new content
	# A once:false non-bark that's already been seen slips past select's seen-filter;
	# the indicator is for the unseen, so guard it here too.
	if (save_state.get("story", {}).get("seen", []) as Array).has(best):
		return ""
	return "!!" if str(def.get("source", "")) == "spine" else "!"


## A snippet's owner — the character whose talk menu offers it (first speaker).
static func owner_of(def: Dictionary) -> String:
	var speakers: Array = def.get("speakers", [])
	return str(speakers[0]) if not speakers.is_empty() else ""


## Speaker ids whose on-screen label is NOT the capitalized id. Load-bearing for the
## second bearer (voice-guides.md, locked 2026-07-03): her data id is `linnea` but the
## name is NEVER spoken or shown in Act I — the UI labels her "The Woman" (the name
## arrives with Act II). Pure so it's unit-testable; DialoguePanel renders through it.
const DISPLAY_NAMES := {"linnea": "The Woman"}


## The label the dialogue box shows for a line's `who` ("" = narration, shown as a dash
## by the panel). Everyone but the mapped ids is just the id capitalized.
static func display_name(who: String) -> String:
	return str(DISPLAY_NAMES.get(who, who.capitalize()))


static func eligible(def: Dictionary, save_state: Dictionary) -> bool:
	var story: Dictionary = save_state.get("story", {})
	var id := str(def.get("id", ""))
	var runs := int((story.get("counters", {}) as Dictionary).get("runs", 0))
	# `once` (default true for everything but barks) — never repeat.
	var is_bark := str(def.get("source", "")) == "bark"
	if bool(def.get("once", not is_bark)) and (story.get("seen", []) as Array).has(id):
		return false
	# A snippet whose `sets_flag` flag is ALREADY set has nothing left to say — skip
	# it. Small, general rule that keeps two twin-gated beats (a beat + its fallback
	# copy, both setting the same flag; the AND-only vocabulary has no negation to do
	# this in data) from BOTH playing: once either sets the flag, the other is inert.
	var sets_flag := str(def.get("sets_flag", "")) if def.get("sets_flag") != null else ""
	if not sets_flag.is_empty() and bool((story.get("flags", {}) as Dictionary).get(sets_flag, false)):
		return false
	# cooldown_runs: min runs between repeats (barks / repeatables)…
	var cooldown := int(def.get("cooldown_runs", 1 if str(def.get("source", "")) == "arc" else 0))
	var last_run: Dictionary = story.get("dialogue_last", {})
	if last_run.has(id) and runs - int(last_run[id]) < cooldown:
		return false
	# …and between two scenes of the SAME character's arc (default 1: never
	# back-to-back — spec).
	if str(def.get("source", "")) == "arc":
		var arc_last: Dictionary = story.get("arc_last", {})
		var who := owner_of(def)
		if arc_last.has(who) and runs - int(arc_last[who]) < maxi(cooldown, 1):
			return false
	for cond: Dictionary in def.get("conditions", []):
		if not eval_condition(cond, save_state):
			return false
	return true


## One condition from the spec vocabulary. ALL conditions on a snippet must hold
## (AND only — no OR in v1; write two snippets instead).
static func eval_condition(cond: Dictionary, save_state: Dictionary) -> bool:
	var story: Dictionary = save_state.get("story", {})
	var tech: Dictionary = save_state.get("tech", {})
	if cond.has("flag"):
		return bool((story.get("flags", {}) as Dictionary).get(str(cond["flag"]), false))
	if cond.has("counter"):
		var counters: Dictionary = story.get("counters", {})
		# codex_shards reads the codex section; the rest are story counters, read
		# generically: runs / deaths / dissolves / boss_kills / full_clears /
		# max_floor (deepest floor ever reached, max()'d on run_ended — 2026-07-10).
		# A counter absent from an old save reads 0.
		var value := float(save_state.get("codex", {}).get("shards", 0)) \
			if str(cond["counter"]) == "codex_shards" \
			else float(counters.get(str(cond["counter"]), 0))
		return value >= float(cond.get("gte", 0))
	if cond.has("tech"):
		return (tech.get("researched", []) as Array).has(str(cond["tech"]))
	if cond.has("tech_started"):
		var node := str(cond["tech_started"])
		return (tech.get("in_progress", {}) as Dictionary).has(node) \
			or (tech.get("researched", []) as Array).has(node)
	if cond.has("age"):
		return int((save_state.get("town", {}) as Dictionary).get("age", 1)) >= int(cond["age"])
	if cond.has("resource"):
		var ledger: Dictionary = save_state.get("ledger", {})
		return float(ledger.get(str(cond["resource"]), 0.0)) >= float(cond.get("gte", 0))
	if cond.has("building"):
		var town: Dictionary = save_state.get("town", {})
		return TownCore.building_level(town, str(cond["building"])) >= int(cond.get("gte", 1))
	if cond.has("has"):
		# First-time-pickup flag, maintained from resource_changed (game.gd).
		return bool((story.get("flags", {}) as Dictionary).get("has-" + str(cond["has"]), false))
	if cond.has("talked_to"):
		var talked: Dictionary = story.get("talked_to", {})
		return int(talked.get(str(cond["talked_to"]), 0)) >= int(cond.get("gte", 1))
	push_error("DialogueCore: unknown condition %s" % str(cond))
	return false


## Bookkeeping after a snippet finished playing: seen, sets_flag, cooldown stamps,
## and (when told) the talked_to counter. Returns a NEW story section.
static func mark_shown(story: Dictionary, def: Dictionary, count_talk: bool = false) -> Dictionary:
	var out := story.duplicate(true)
	var id := str(def.get("id", ""))
	var runs := int((out.get("counters", {}) as Dictionary).get("runs", 0))
	if not (out.get("seen", []) as Array).has(id):
		if not out.has("seen"):
			out["seen"] = []
		(out["seen"] as Array).append(id)
	var flag := str(def.get("sets_flag", "")) if def.get("sets_flag") != null else ""
	if not flag.is_empty():
		if not out.has("flags"):
			out["flags"] = {}
		(out["flags"] as Dictionary)[flag] = true
	if not out.has("dialogue_last"):
		out["dialogue_last"] = {}
	(out["dialogue_last"] as Dictionary)[id] = runs
	if str(def.get("source", "")) == "arc":
		if not out.has("arc_last"):
			out["arc_last"] = {}
		(out["arc_last"] as Dictionary)[owner_of(def)] = runs
	if count_talk:
		if not out.has("talked_to"):
			out["talked_to"] = {}
		var talked: Dictionary = out["talked_to"]
		talked[owner_of(def)] = int(talked.get(owner_of(def), 0)) + 1
	return out
