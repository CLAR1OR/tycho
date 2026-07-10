extends RefCounted
class_name TechCore
## Pure tech-tree logic (PRD §7.8, architecture-schemas.md §4). Operates on the
## save's `tech` section (`{researched: [], in_progress: {id: knowledge},
## auto_solve_counters: {id: runs}, quiz_locked: {id: true}, active: ""}`) and on
## defs from data/tech/. All functions return NEW dicts — no engine state,
## unit-tests headless.
##
## Flow: pour Knowledge into the active node (investing spends KNOWLEDGE ONLY — the
## Knowledge Shards you bring back are converted to Knowledge separately, by turning
## them in to Sophia at the desk; see TechState.turn_in_shards) → at cost threshold
## it's READY → read explanation → solve puzzle/quiz → complete() → the typed
## unlocks fire (dispatched by the caller). Sophia auto-solves the active node after
## `auto_solve_after_runs` runs (IC-10: reward thinking, never hard-gate on it).
##
## Quiz gate (2026-07-06): a WRONG quiz answer locks that node's quiz (quiz_locked)
## until one more run passes — the lock is cleared on run_ended (TechState). The
## interactive arch puzzle is exempt (its staged failures are the teaching).

## What one Knowledge Shard is worth once turned in for Knowledge at Sophia's desk
## (PRD §7.10 — the main early research driver; boss bounty). Placeholder economy
## number: a shard must beat a passive day tick so run loot stays the early driver.
const SHARD_KNOWLEDGE_VALUE := 5.0


## Node ids the player may research now: prereqs met, not yet researched.
static func available(defs: Dictionary, tech: Dictionary) -> Array[String]:
	var researched: Array = tech.get("researched", [])
	var out: Array[String] = []
	for id: String in defs:
		if id in researched:
			continue
		var ok := true
		for req: String in (defs[id] as Dictionary).get("prereqs", []):
			if req not in researched:
				ok = false
				break
		if ok:
			out.append(id)
	out.sort()
	return out


static func progress(tech: Dictionary, id: String) -> float:
	return float(tech.get("in_progress", {}).get(id, 0.0))


static func is_ready(def: Dictionary, tech: Dictionary) -> bool:
	return progress(tech, str(def.get("id", ""))) >= float(def.get("cost_knowledge", 0.0))


## Pour up to `amount` knowledge into a node. Returns {"tech": new dict,
## "accepted": how much the node actually absorbed} — the caller only spends
## the accepted part from the Ledger.
static func invest(tech: Dictionary, def: Dictionary, amount: float) -> Dictionary:
	var id := str(def.get("id", ""))
	var out := tech.duplicate(true)
	var cur := progress(out, id)
	var accepted := clampf(float(def.get("cost_knowledge", 0.0)) - cur, 0.0, maxf(amount, 0.0))
	if accepted > 0.0:
		out["in_progress"][id] = cur + accepted
	return {"tech": out, "accepted": accepted}


## Mark a node researched (after its puzzle/quiz/auto-solve). Clears its progress
## and counter; deactivates it if it was active.
static func complete(tech: Dictionary, id: String) -> Dictionary:
	var out := tech.duplicate(true)
	if id not in out["researched"]:
		out["researched"].append(id)
	out["in_progress"].erase(id)
	out["auto_solve_counters"].erase(id)
	if str(out.get("active", "")) == id:
		out["active"] = ""
	return out


## One run went by with `id` as the active node: tick its auto-solve counter.
static func tick_auto_solve(tech: Dictionary, id: String) -> Dictionary:
	if id.is_empty():
		return tech.duplicate(true)
	var out := tech.duplicate(true)
	out["auto_solve_counters"][id] = int(out["auto_solve_counters"].get(id, 0)) + 1
	return out


## Sophia finishes it for you once the counter reaches the node's threshold —
## but only when the node is READY (fully funded); reading/solving is what's
## being waived, not the Knowledge cost.
static func auto_solve_ready(def: Dictionary, tech: Dictionary) -> bool:
	var id := str(def.get("id", ""))
	var threshold := int(def.get("auto_solve_after_runs", 0))
	if threshold <= 0 or not is_ready(def, tech):
		return false
	return int(tech.get("auto_solve_counters", {}).get(id, 0)) >= threshold


## Knowledge yielded by turning in `shards` whole Knowledge Shards at Sophia's desk
## (all held shards convert at SHARD_KNOWLEDGE_VALUE apiece). Whole shards only.
## `bonus_per_shard` adds on top of the base value (the Cathedral's completion bonus:
## TownCore.capability_value(town, defs, "shard_value_add") at the call site —
## town-economy.md, 2026-07-10). Negative bonuses clamp to 0 (never below base).
static func shard_turn_in_value(shards: float, bonus_per_shard: float = 0.0) -> float:
	return floorf(maxf(shards, 0.0)) * (SHARD_KNOWLEDGE_VALUE + maxf(bonus_per_shard, 0.0))


# --- Quiz lock (a wrong quiz answer waits one run; 2026-07-06) -----------------------

## True while `id`'s quiz is locked (a wrong answer this run — Sophia won't hear it
## again until a run passes). Quiz nodes only; the interactive puzzle never locks.
static func is_quiz_locked(tech: Dictionary, id: String) -> bool:
	return bool(tech.get("quiz_locked", {}).get(id, false))


## Lock `id`'s quiz after a wrong answer. Returns a NEW tech dict.
static func lock_quiz(tech: Dictionary, id: String) -> Dictionary:
	var out := tech.duplicate(true)
	if not out.has("quiz_locked"):
		out["quiz_locked"] = {}
	out["quiz_locked"][id] = true
	return out


## Clear every quiz lock (one run has passed — call on run_ended). Returns a NEW dict.
static func clear_quiz_locks(tech: Dictionary) -> Dictionary:
	var out := tech.duplicate(true)
	out["quiz_locked"] = {}
	return out
