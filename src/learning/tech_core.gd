extends RefCounted
class_name TechCore
## Pure tech-tree logic (PRD §7.8, architecture-schemas.md §4). Operates on the
## save's `tech` section (`{researched: [], in_progress: {id: knowledge},
## auto_solve_counters: {id: runs}, active: ""}`) and on defs from data/tech/.
## All functions return NEW dicts — no engine state, unit-tests headless.
##
## Flow: pick an active node → pour Knowledge (+ Knowledge Shards) into it →
## at cost threshold it's READY → read explanation → solve puzzle/quiz → complete()
## → the typed unlocks fire (dispatched by the caller). Linnea auto-solves the
## active node after `auto_solve_after_runs` runs (IC-10: reward thinking, never
## hard-gate on it).

## What one Knowledge Shard is worth when dumped into research (PRD §7.10 — the
## main early research driver; boss bounty). Placeholder economy number.
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


## Linnea finishes it for you once the counter reaches the node's threshold —
## but only when the node is READY (fully funded); reading/solving is what's
## being waived, not the Knowledge cost.
static func auto_solve_ready(def: Dictionary, tech: Dictionary) -> bool:
	var id := str(def.get("id", ""))
	var threshold := int(def.get("auto_solve_after_runs", 0))
	if threshold <= 0 or not is_ready(def, tech):
		return false
	return int(tech.get("auto_solve_counters", {}).get(id, 0)) >= threshold


## Convert whole shards into knowledge for research. Pure math: how many of
## `shards` are needed to top `missing` up, given `knowledge` already available.
## Returns {"shards_used": int, "knowledge_from_shards": float}.
static func shards_needed(missing: float, knowledge: float, shards: float) -> Dictionary:
	var gap := maxf(missing - knowledge, 0.0)
	var used := mini(int(ceilf(gap / SHARD_KNOWLEDGE_VALUE)), int(shards))
	return {"shards_used": used, "knowledge_from_shards": float(used) * SHARD_KNOWLEDGE_VALUE}
