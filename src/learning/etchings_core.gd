extends RefCounted
class_name EtchingsCore
## Pure etchings logic (design/etchings.md, PRD §7.3). The 9 active abilities live as
## data (data/etchings/*.json); this class owns the save-side bookkeeping — what's
## unlocked, what a level costs, learning/equipping, and the level-scaled behavior
## numbers the player reads when it casts. No engine state — unit-tested headless.
##
## Operates on the save's `combat.etchings` section:
##   {slots: {rmb: id, q: id, r: id}, unlocked: {id: level}}   (schema §1, no change)
##
## STYLE: return-a-new-dict, like TechCore (NOT StoryCore's in-place). Every mutating
## call returns a fresh dict — callers MUST reassign (`etchings = EtchingsCore.learn(
## etchings, id)`) or the change is lost. Reads are direct.
##
## IMPLEMENTATION STATUS is CODE, not data: all 9 abilities SHIP as data, but only the
## five in IMPLEMENTED are learnable/castable in v1 — the other four are DORMANT (visible
## in the panel, not learnable). See design/etchings.md "Implementation status".

## The five abilities with real cast behavior in v1. The other four (afterstrike, ward,
## lodestone, sentinel) ship as data but are dormant — can_learn() gates on this.
const IMPLEMENTED: Array[String] = ["push", "bolt", "snare", "shockwave", "surge"]

const MAX_LEVEL := 3

static var _defs_cache: Dictionary = {}


## All etching definitions {id: def}, cached after the first load.
static func defs() -> Dictionary:
	if _defs_cache.is_empty():
		_defs_cache = DataLoader.load_domain("etchings")
	return _defs_cache


static func is_implemented(id: String) -> bool:
	return id in IMPLEMENTED


static func is_unlocked(etchings: Dictionary, id: String) -> bool:
	return level_of(etchings, id) >= 1


static func level_of(etchings: Dictionary, id: String) -> int:
	return int((etchings.get("unlocked", {}) as Dictionary).get(id, 0))


## Dust cost of the NEXT learn step for a node at `current_level`: unlock (0 → 1) reads
## cost_unlock_dust; levelling (1 → 2, 2 → 3) reads cost_levels_dust[level-1]. Returns -1
## when maxed (already L3).
static func learn_cost(def: Dictionary, current_level: int) -> int:
	if current_level <= 0:
		return int(def.get("cost_unlock_dust", 0))
	if current_level >= MAX_LEVEL:
		return -1
	var levels: Array = def.get("cost_levels_dust", [])
	var idx := current_level - 1
	return int(levels[idx]) if idx < levels.size() else -1


## Can the player learn/level this node right now? Dormant (non-implemented) nodes are
## never learnable; maxed nodes aren't; otherwise it's an affordability check.
static func can_learn(def: Dictionary, dust: float, etchings: Dictionary) -> bool:
	var id := str(def.get("id", ""))
	if not is_implemented(id):
		return false
	var level := level_of(etchings, id)
	if level >= MAX_LEVEL:
		return false
	var cost := learn_cost(def, level)
	return cost >= 0 and dust >= float(cost)


## Learn (or level up) `id` — level 0 → 1 on first learn, then +1 to a cap of MAX_LEVEL.
## Pure: returns a NEW etchings dict (does NOT spend Dust — the caller owns the Ledger).
static func learn(etchings: Dictionary, id: String) -> Dictionary:
	var out := etchings.duplicate(true)
	if not out.has("unlocked"):
		out["unlocked"] = {}
	out["unlocked"][id] = mini(MAX_LEVEL, level_of(etchings, id) + 1)
	return out


## Equip `id` into `slot` (rmb|q|r). `id` must be unlocked and its def.slot must match
## the slot; empty string = unequip. Invalid requests push_error and return unchanged.
## Returns a NEW etchings dict.
static func equip(etchings: Dictionary, slot: String, id: String, all_defs: Dictionary) -> Dictionary:
	var out := etchings.duplicate(true)
	if not out.has("slots"):
		out["slots"] = {"rmb": "", "q": "", "r": ""}
	if not out["slots"].has(slot):
		push_error("EtchingsCore.equip: unknown slot \"%s\"" % slot)
		return out
	if id.is_empty():
		out["slots"][slot] = ""
		return out
	if not all_defs.has(id):
		push_error("EtchingsCore.equip: unknown etching \"%s\"" % id)
		return out
	if str((all_defs[id] as Dictionary).get("slot", "")) != slot:
		push_error("EtchingsCore.equip: \"%s\" is not a %s ability" % [id, slot])
		return out
	if not is_unlocked(out, id):
		push_error("EtchingsCore.equip: \"%s\" is not unlocked" % id)
		return out
	out["slots"][slot] = id
	return out


## Grant the tutorial ability (Push, level 1) and auto-equip it to an empty RMB slot when
## the B2 flag is set (design/etchings.md: Thomas grants Push during the meditation scene).
## Idempotent — safe to call on every panel open + player spawn. Returns a NEW dict.
static func ensure_baseline(etchings: Dictionary, all_defs: Dictionary, flags: Dictionary) -> Dictionary:
	var out := etchings.duplicate(true)
	if not bool(flags.get("b2", false)) or not all_defs.has("push"):
		return out
	if level_of(out, "push") < 1:
		out = learn(out, "push")
	if str((out.get("slots", {}) as Dictionary).get("rmb", "")) == "":
		out = equip(out, "rmb", "push", all_defs)
	return out


## The behavior numbers for a node at `level`, with each level's `<field>_mult` folded
## into the base `behavior` dict (design/etchings.md L2 stat mults). Pure; the player
## reads this when it casts. L3 riders (`{"rider": ...}`) carry no _mult and are NOT
## applied — riders are unimplemented in v1.
static func effective_behavior(def: Dictionary, level: int) -> Dictionary:
	var out: Dictionary = (def.get("behavior", {}) as Dictionary).duplicate(true)
	var levels: Array = def.get("levels", [])
	# levels[0] = L1 (base, empty), levels[1] = L2, levels[2] = L3 — apply up to `level`.
	for lvl in range(1, mini(level, levels.size())):
		var entry: Dictionary = levels[lvl]
		for key: String in entry:
			if not key.ends_with("_mult"):
				continue
			var base_key := key.trim_suffix("_mult")
			if out.has(base_key):
				out[base_key] = float(out[base_key]) * float(entry[key])
	return out
