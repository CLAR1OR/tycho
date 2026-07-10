extends RefCounted
class_name AttunementsCore
## Pure Passive Attunements logic (bible "Passive Attunements", PRD §7.4). The seven
## attunements are the persistent passive BASELINE a run starts from — echoes build on
## top (PRD: base feel exports → weapon → attunements → echoes). Content lives as data
## (data/attunements/*.json); this class owns the save-side bookkeeping and folds each
## owned attunement's CURRENT level into the numbers the run reads at player spawn. No
## engine state — unit-tested headless.
##
## Operates on the save's `combat.attunements` section: a flat {id: level} map (level
## 1..3; absent id = level 0, un-owned). Purchases spend Resonance Dust (the SAME sink
## as active etchings — every Dust here is Dust not spent on an ability; the two-sink
## tension is deliberate, bible).
##
## STYLE: return-a-new-dict, like TechCore / EtchingsCore (NOT StoryCore's in-place).
## `deepen` returns a fresh dict — callers MUST reassign. Reads are direct.
##
## LEVELS ARE ABSOLUTE/REPLACE: a level entry states the attunement's TOTAL effect at
## that level (like building levels, not stacking deltas). Each `levels[i]` entry carries
## a `kind` (constant across an attunement's levels) that routes it:
##   stat            → echo-shape {stat, add, mult} mods (max_health / dash_cooldown /
##                     attack_damage[_finisher]) folded through EchoCore's SAME math
##   heal_on_clear   → pct of MISSING hp restored when a room clears (Recovery)
##   find_rate       → multiplier on Dust/Ore find (Attunement)
##   damage_reduction→ flat hp subtracted from each hit taken, floored at 1 (Resilience)
##   ability_cooldown→ multiplier on ability cast cooldowns (Resonance Flow — EchoCore has
##                     no ability-cooldown stat handle, so this rides a player-side var)

const MAX_LEVEL := 3

static var _defs_cache: Dictionary = {}


## All attunement definitions {id: def}, cached after the first load.
static func defs() -> Dictionary:
	if _defs_cache.is_empty():
		_defs_cache = DataLoader.load_domain("attunements")
	return _defs_cache


## Owned level of `id` (0 = un-owned).
static func level(attunements: Dictionary, id: String) -> int:
	return int(attunements.get(id, 0))


## Dust cost of the NEXT deepen step from `level_now` (0→1 reads costs_dust[0], 1→2
## reads [1], 2→3 reads [2]). Returns -1 when already at MAX.
static func next_cost(def: Dictionary, level_now: int) -> int:
	if level_now >= MAX_LEVEL:
		return -1
	var costs: Array = def.get("costs_dust", [])
	return int(costs[level_now]) if level_now < costs.size() else -1


## Can this attunement be deepened right now? Not at MAX, and Dust covers the next cost.
static func can_deepen(def: Dictionary, dust: float, attunements: Dictionary) -> bool:
	var lvl := level(attunements, str(def.get("id", "")))
	if lvl >= MAX_LEVEL:
		return false
	var cost := next_cost(def, lvl)
	return cost >= 0 and dust >= float(cost)


## Deepen `id` by one level, capped at MAX. Pure: returns a NEW dict (does NOT spend
## Dust — the caller owns the Ledger).
static func deepen(attunements: Dictionary, id: String) -> Dictionary:
	var out := attunements.duplicate(true)
	out[id] = mini(MAX_LEVEL, level(attunements, id) + 1)
	return out


## The current level's effect entry for an owned attunement, or {} when un-owned / missing.
static func _level_entry(attunements: Dictionary, all_defs: Dictionary, id: String) -> Dictionary:
	var lvl := level(attunements, id)
	if lvl < 1 or not all_defs.has(id):
		return {}
	var levels: Array = (all_defs[id] as Dictionary).get("levels", [])
	if lvl - 1 >= levels.size():
		return {}
	return levels[lvl - 1]


## The combined echo-shape stat mods for ALL owned stat-kind attunements at their current
## levels (each is absolute — vitality L2 contributes +40 max_health, not +20 then +40).
## Feed straight into EchoCore.apply_to_player({"mods": ...}) — the SAME application path
## as weapons/echoes, no duplicate math.
static func stat_mods(attunements: Dictionary, all_defs: Dictionary) -> Array:
	var out: Array = []
	for id: String in attunements:
		var e := _level_entry(attunements, all_defs, id)
		if str(e.get("kind", "")) == "stat":
			for m: Dictionary in e.get("mods", []):
				out.append(m)
	return out


## Recovery: pct of missing HP restored on room clear (0.0 when un-owned).
static func heal_on_clear_pct(attunements: Dictionary, all_defs: Dictionary) -> float:
	var pct := 0.0
	for id: String in attunements:
		var e := _level_entry(attunements, all_defs, id)
		if str(e.get("kind", "")) == "heal_on_clear":
			pct += float(e.get("pct", 0.0))
	return pct


## Attunement: the find-rate multiplier on Dust/Ore rewards (1.0 baseline).
static func find_rate_mult(attunements: Dictionary, all_defs: Dictionary) -> float:
	var mult := 1.0
	for id: String in attunements:
		var e := _level_entry(attunements, all_defs, id)
		if str(e.get("kind", "")) == "find_rate":
			mult *= float(e.get("mult", 1.0))
	return mult


## Resilience: flat hp subtracted from each hit taken (0 baseline; the player floors
## post-reduction damage at 1 — no immunity).
static func damage_reduction(attunements: Dictionary, all_defs: Dictionary) -> int:
	var dr := 0
	for id: String in attunements:
		var e := _level_entry(attunements, all_defs, id)
		if str(e.get("kind", "")) == "damage_reduction":
			dr += int(e.get("amount", 0))
	return dr


## Resonance Flow: multiplier on ability cast cooldowns (1.0 baseline). EchoCore has no
## ability-cooldown stat handle, so the player consumes this where per-slot cooldowns start.
static func ability_cooldown_mult(attunements: Dictionary, all_defs: Dictionary) -> float:
	var mult := 1.0
	for id: String in attunements:
		var e := _level_entry(attunements, all_defs, id)
		if str(e.get("kind", "")) == "ability_cooldown":
			mult *= float(e.get("mult", 1.0))
	return mult
