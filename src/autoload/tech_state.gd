extends Node
## TechState autoload — owner of the save's tech-section bookkeeping (PRD §7.8,
## architecture-schemas.md §4). Thin by rule: it subscribes to run_ended for Sophia's
## auto-solve (and to clear quiz locks — a wrong quiz answer waits one run), exposes the
## mutation entry points the research/cheat panels call (set_active / invest /
## turn_in_shards / lock_quiz / complete), and writes SaveManager.state["tech"]. It holds
## NO state of its own — the tech dict lives
## in the save (SaveManager.state). The pure logic already exists and is untouched:
## TechCore (src/learning/tech_core.gd, tested in tests/core/tech_core_test.gd). This
## autoload just centralizes the mutation call sites that used to be scattered across
## game.gd, tech_panel.gd, and cheat_panel.gd.
##
## RETURN-A-NEW-DICT hazard: unlike StoryCore (which mutates in place), TechCore returns
## fresh dicts, so every mutation here REASSIGNS SaveManager.state["tech"]. Call sites
## must re-fetch state["tech"] after any TechState call and must never hold the dict
## across one (same hazard class as DialogueCore.mark_shown). The panel readouts already
## re-read state on each screen, so they're safe.
##
## ORDERING GUARANTEE (relied on by the save path): autoloads run _ready() before the
## main scene (game.tscn), so TechState connects to run_ended BEFORE game.gd does — the
## auto-solve result is in state before game.gd's deferred town-return save persists it.
## The smoke re-reads the slot file after a run to prove the researched/active/counter
## state landed on disk. Registered in project.godot [autoload] right after StoryState
## (the other target-only state autoload) and before RunState.
##
## OUT OF SCOPE (stays in game.gd, same reasoning as the day tick): the
## `_on_tech_researched` age-advance hook mutates town/meta.age, not the tech section —
## it's a downstream reaction to the tech_researched signal, not a tech mutation.


func _ready() -> void:
	EventBus.run_ended.connect(_on_run_ended)


# --- EventBus handlers -------------------------------------------------------------

## Sophia works the ACTIVE node between runs; after enough runs she just solves it —
## reward thinking, never hard-gate on the puzzle (IC-10, PRD §7.8). Moved verbatim
## from game.gd's _on_run_ended; the complete step routes through complete() so the
## `TechCore.complete + tech_researched` pair lives in exactly one place.
func _on_run_ended(_victory: bool, _floor_reached: int, _stats: Dictionary) -> void:
	# A run has passed: clear any quiz locks (a wrong quiz answer waits exactly one
	# run before Sophia will hear the answer again — 2026-07-06, PRD §7.8).
	SaveManager.state["tech"] = TechCore.clear_quiz_locks(SaveManager.state["tech"])
	var active := str(SaveManager.state["tech"].get("active", ""))
	if active.is_empty():
		return
	SaveManager.state["tech"] = TechCore.tick_auto_solve(SaveManager.state["tech"], active)
	var tech_defs := DataLoader.load_domain("tech")
	if tech_defs.has(active) and TechCore.auto_solve_ready(tech_defs[active], SaveManager.state["tech"]):
		complete(active)


# --- Public API (only where a call site already exists) ----------------------------

## Make `id` the ACTIVE node — the one Sophia auto-solves over runs (tech_panel's node
## selection).
func set_active(id: String) -> void:
	SaveManager.state["tech"]["active"] = id


## Pour the Ledger's Knowledge into `def`'s node, up to its remaining cost. Investing
## spends KNOWLEDGE ONLY (2026-07-06) — Knowledge Shards no longer auto-convert here;
## the player turns them in for Knowledge separately (turn_in_shards). The Ledger spend
## is part of this transaction (spend only the accepted part, so the write and the spend
## stay atomic; reason "research"). Returns the accepted knowledge for readout.
func invest(def: Dictionary, node_id: String) -> float:
	var tech: Dictionary = SaveManager.state["tech"]
	var missing := float(def["cost_knowledge"]) - TechCore.progress(tech, node_id)
	var result := TechCore.invest(tech, def, minf(Ledger.get_amount("knowledge"), missing))
	if float(result["accepted"]) > 0.0 and Ledger.try_spend("knowledge", float(result["accepted"]), "research"):
		SaveManager.state["tech"] = result["tech"]
	return float(result["accepted"])


## Turn in ALL held Knowledge Shards for Knowledge at Sophia's desk (the shards you
## bring back; she extracts what they teach). Converts whole shards at
## SHARD_KNOWLEDGE_VALUE apiece — spend "knowledge-shards", add "knowledge", both under
## reason "shard-turn-in", atomic like invest. Returns the Knowledge gained (0 at none).
func turn_in_shards() -> float:
	var whole := floorf(Ledger.get_amount("knowledge-shards"))
	if whole <= 0.0:
		return 0.0
	var gained := TechCore.shard_turn_in_value(whole)
	if Ledger.try_spend("knowledge-shards", whole, "shard-turn-in"):
		Ledger.add("knowledge", gained, "shard-turn-in")
		return gained
	return 0.0


## Lock `id`'s quiz after a wrong answer (a wrong quiz answer waits one run; the lock
## clears on the next run_ended). Reassigns state["tech"] — the return-a-new-dict rule.
func lock_quiz(id: String) -> void:
	SaveManager.state["tech"] = TechCore.lock_quiz(SaveManager.state["tech"], id)


## Mark `id` researched and announce it. The single home of the `TechCore.complete +
## tech_researched` pair (previously duplicated in the panel, the cheat panel, and the
## auto-solve block). Saving stays with the caller (the panel saves after; the cheat
## panel saves after; the auto-solve rides game.gd's deferred town-return save).
func complete(id: String) -> void:
	SaveManager.state["tech"] = TechCore.complete(SaveManager.state["tech"], id)
	EventBus.tech_researched.emit(id)
