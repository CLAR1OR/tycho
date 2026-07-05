extends Node
## TechState autoload — owner of the save's tech-section bookkeeping (PRD §7.8,
## architecture-schemas.md §4). Thin by rule: it subscribes to run_ended for Sophia's
## auto-solve, exposes the mutation entry points the research/cheat panels call, and
## writes SaveManager.state["tech"]. It holds NO state of its own — the tech dict lives
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


## Pour the Ledger's Knowledge (+ Knowledge Shards, converted as needed) into `def`'s
## node, up to its remaining cost. The Ledger spends are part of this transaction (spend
## only the accepted part, so the write and the spend stay atomic — the exact behavior
## and reasons from tech_panel's invest_all). Returns the accepted knowledge for readout.
func invest(def: Dictionary, node_id: String) -> float:
	var tech: Dictionary = SaveManager.state["tech"]
	var missing := float(def["cost_knowledge"]) - TechCore.progress(tech, node_id)
	var conv := TechCore.shards_needed(missing, Ledger.get_amount("knowledge"), Ledger.get_amount("knowledge-shards"))
	if int(conv["shards_used"]) > 0 and Ledger.try_spend("knowledge-shards", float(conv["shards_used"]), "research"):
		Ledger.add("knowledge", float(conv["knowledge_from_shards"]), "shard-conversion")
	var result := TechCore.invest(tech, def, minf(Ledger.get_amount("knowledge"), missing))
	if float(result["accepted"]) > 0.0 and Ledger.try_spend("knowledge", float(result["accepted"]), "research"):
		SaveManager.state["tech"] = result["tech"]
	return float(result["accepted"])


## Mark `id` researched and announce it. The single home of the `TechCore.complete +
## tech_researched` pair (previously duplicated in the panel, the cheat panel, and the
## auto-solve block). Saving stays with the caller (the panel saves after; the cheat
## panel saves after; the auto-solve rides game.gd's deferred town-return save).
func complete(id: String) -> void:
	SaveManager.state["tech"] = TechCore.complete(SaveManager.state["tech"], id)
	EventBus.tech_researched.emit(id)
