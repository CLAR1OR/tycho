extends RefCounted
class_name BuildPanelCore
## Pure helpers for the town-building screens — "Herzog's ledger" (B2) + "The survey" (B3)
## (human-picked 2026-07-09 via claude.ai/design, group "Town Building"). The two panels ask
## the same handful of questions about a building def; this class answers them without touching
## engine state (unit-tested headless). ALL cost/level math is delegated to TownCore — nothing
## is duplicated here.
##
## The current build level is read at the call site with TownCore.building_level(town, id) and
## passed in as `level`, so this core never reaches into SaveManager.
##
## HUMAN: the copy strings below (YIELD formats + the capability flavor) are PLACEHOLDERS —
## dial them freely (Herzog's/Mara's register: short declaratives, no aphorisms, no em dashes).

# =====================================================================================
# Copy — placeholders. (The yield lines the ledger + survey rows read.)
# =====================================================================================
const YIELD_PRODUCE := "%d %s a day"          # "3 food a day"
const YIELD_KNOWLEDGE := "%d knowledge a day"  # a knowledge effect has no `resource` field
const CAP_FLAVOR := "the town stands behind stone"  # capability effects (town walls) — flavor

## Deterministic survey row order: the known buildings first (a designed reading order), then
## any future/unknown building id appended sorted — a new building never crashes the survey.
const DISPLAY_ORDER: Array = ["sophias-study", "farm", "quarry", "town-walls"]


## One yield line for a level's `effects` list → {"text": String, "resource": String}.
## resource is "" for capability/flavor effects (no resource colour). Reads the first effect
## that produces a line (buildings have one production effect per level in v1).
static func yield_line(effects: Array) -> Dictionary:
	for effect: Dictionary in effects:
		match str(effect.get("kind", "")):
			"produce":
				var res := str(effect.get("resource", ""))
				return {"text": YIELD_PRODUCE % [int(effect.get("per_day", 0)), res], "resource": res}
			"knowledge":
				return {"text": YIELD_KNOWLEDGE % int(effect.get("per_day", 0)), "resource": "knowledge"}
			"capability":
				return {"text": CAP_FLAVOR, "resource": ""}
			_:
				pass
	return {"text": "", "resource": ""}


## The three ledger entries for `def` at `current_level`, one per `def.levels` row:
##   {"level": 1-based int, "state": "built"|"next"|"beyond", "yield": {text,resource}, "cost": {}}
## built = already bought, next = the one to buy, beyond = further levels.
static func entry_rows(def: Dictionary, current_level: int) -> Array:
	var levels: Array = def.get("levels", [])
	var out: Array = []
	for i in levels.size():
		var lvl: Dictionary = levels[i]
		var state := "built" if i < current_level else ("next" if i == current_level else "beyond")
		out.append({
			"level": i + 1,
			"state": state,
			"yield": yield_line(lvl.get("effects", [])),
			"cost": lvl.get("cost", {}),
		})
	return out


## The build action for `def` at `current_level`:
##   {"kind": "build", "cost": {}, "to_level": 1}      — L0, the first build
##   {"kind": "raise", "cost": {}, "to_level": n+1}    — mid-track upgrade
##   {"kind": "maxed", "cost": {}, "to_level": level}  — the 3 levels are full
## Cost comes from TownCore.next_level_cost (the level's cost dict).
static func action(def: Dictionary, current_level: int) -> Dictionary:
	var cost := TownCore.next_level_cost(def, current_level)
	if cost.is_empty():
		return {"kind": "maxed", "cost": {}, "to_level": current_level}
	var kind := "build" if current_level == 0 else "raise"
	return {"kind": kind, "cost": cost, "to_level": current_level + 1}


## The ordered, unique resource ids appearing across ALL of `def`'s level costs — the set the
## carry readout shows for this building (typically [gold, stone]). First-seen order preserved.
static func carry_resources(def: Dictionary) -> Array:
	var out: Array = []
	for lvl: Dictionary in def.get("levels", []):
		for id: String in (lvl.get("cost", {}) as Dictionary):
			if not out.has(id):
				out.append(id)
	return out


## The deterministic survey row order for the loaded `defs`: DISPLAY_ORDER first (only ids that
## exist), then any remaining ids appended in sorted order (a new building never crashes it).
static func survey_order(defs: Dictionary) -> Array:
	var out: Array = []
	for id in DISPLAY_ORDER:
		if defs.has(id):
			out.append(id)
	var extras: Array = []
	for id: String in defs:
		if not out.has(id):
			extras.append(id)
	extras.sort()
	return out + extras
