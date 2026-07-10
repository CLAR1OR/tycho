extends RefCounted
class_name BossCore
## Pure sequencing core for floor bosses (design/bosses/floor-1-boss.md §2 — the
## boss grammar all five bosses inherit). Owns every sequencing DECISION: phase
## selection off HP thresholds, attack-loop stepping, reconfigure detection, and
## def validation. No engine types, unit-tested headless (tests/core/
## boss_core_test.gd); the scene (enemy_boss.gd) only executes what this returns.
## Boss content lives in data/bosses/*.json — adding a boss must never need code
## here unless it invents a new move KIND (a per-boss exception, grammar rule 1).

## Move kinds enemy_boss.gd knows how to execute. Adding a kind = implement it in
## the scene AND list it here — validation must stay honest about what actually runs.
const KINDS: Array[String] = ["lunge", "swipe", "circle", "burrow", "erupt", "vent_call"]


## Phase index (0-based) for an HP fraction (1.0 = full HP). A def's thresholds are
## the fraction each phase STARTS at, strictly descending (phase 1 = 1.0); a phase
## is active once hp_fraction is AT or below its threshold — so the Den-Warden's
## 50% crossing lands exactly on <= 0.5.
static func phase_for(def: Dictionary, hp_fraction: float) -> int:
	var phases: Array = def.get("phases", [])
	var idx := 0
	for i in phases.size():
		if hp_fraction <= float((phases[i] as Dictionary).get("threshold", 1.0)):
			idx = i
	return idx


## The move at `loop_position` of a phase's attack loop, plus the wrapped next
## position: {id, move (its def), next_position}. {} for a missing/empty loop —
## defensive only; validate() rejects those shapes at load.
static func next_move(def: Dictionary, phase_index: int, loop_position: int) -> Dictionary:
	var phases: Array = def.get("phases", [])
	if phases.is_empty():
		return {}
	var phase: Dictionary = phases[clampi(phase_index, 0, phases.size() - 1)]
	var loop: Array = phase.get("loop", [])
	if loop.is_empty():
		return {}
	var pos := loop_position % loop.size()
	var id := str(loop[pos])
	return {
		"id": id,
		"move": (def.get("moves", {}) as Dictionary).get(id, {}),
		"next_position": (pos + 1) % loop.size(),
	}


## A transition reconfigures only when the fight moves FORWARD into a later phase.
## (HP can only fall today, but a future heal mechanic must never replay the beat.)
static func should_reconfigure(old_phase: int, new_phase: int) -> bool:
	return new_phase > old_phase


## Sequencing validation the DataLoader shape check can't see: at least 1 phase,
## thresholds strictly descending from 1.0 (and inside (0, 1]), every loop
## non-empty and made of ids that exist in `moves`, every move an executable KIND.
## Returns error strings ([] = valid); callers push_error them (loud, never silent).
static func validate(def: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var where := str(def.get("id", "?"))
	var phases: Array = def.get("phases", [])
	var moves: Dictionary = def.get("moves", {})
	if phases.is_empty():
		errors.append("%s: needs at least 1 phase" % where)
	var prev := INF
	for i in phases.size():
		var phase: Dictionary = phases[i]
		var threshold := float(phase.get("threshold", -1.0))
		if i == 0 and not is_equal_approx(threshold, 1.0):
			errors.append("%s: phase 1's threshold must be 1.0 (got %s)" % [where, threshold])
		if threshold >= prev:
			errors.append("%s: phase thresholds must be strictly descending (phase %d: %s)"
				% [where, i + 1, threshold])
		if threshold <= 0.0 or threshold > 1.0:
			errors.append("%s: phase %d threshold %s outside (0, 1]" % [where, i + 1, threshold])
		prev = threshold
		var loop: Array = phase.get("loop", [])
		if loop.is_empty():
			errors.append("%s: phase %d has an empty loop" % [where, i + 1])
		for mid: Variant in loop:
			if not moves.has(str(mid)):
				errors.append("%s: phase %d loop names unknown move \"%s\"" % [where, i + 1, mid])
	for mid: Variant in moves:
		var kind := str((moves[mid] as Dictionary).get("kind", ""))
		if not KINDS.has(kind):
			errors.append("%s: move \"%s\" has unknown kind \"%s\" (executable: %s)"
				% [where, mid, kind, ", ".join(KINDS)])
	return errors


## The boss def authored for a floor, or {} when none exists — the {} answer IS the
## placeholder-boss path (combat_room falls back to the stats-pumped brute + escorts).
static func def_for_floor(defs: Dictionary, floor_num: int) -> Dictionary:
	for id: String in defs:
		if int((defs[id] as Dictionary).get("floor", -1)) == floor_num:
			return defs[id]
	return {}
