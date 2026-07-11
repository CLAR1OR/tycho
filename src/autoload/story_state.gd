extends Node
## StoryState autoload — owner of the save's story-section bookkeeping (PRD §7.0/§7.11,
## architecture-schemas.md §1). Thin by rule: it subscribes to the EventBus run/economy
## signals, delegates the mutation math to pure StoryCore, and writes SaveManager.state.
## It holds NO state of its own — the story dict lives in the save (SaveManager.state).
##
## This is the migration of the counters/flags that used to live in game.gd's EventBus
## handlers ("a StoryState autoload will own them later"). game.gd now keeps only scene
## flow (music, day tick, tech auto-solve, saving, scene swaps).
##
## ORDERING GUARANTEE (relied on by the save path): autoloads run _ready() before the
## main scene (game.tscn), so StoryState connects to run_ended / death / boss_killed
## BEFORE game.gd does — its handlers therefore fire FIRST for every emit. game.gd's
## own run_ended handler defers the town swap (and the slot save that rides it), so the
## counters StoryState updates here are always on disk by the time the save writes. The
## smoke asserts this by re-reading the slot file after a run ends. Registered in
## project.godot [autoload] right after SaveManager (whose state it owns a slice of) and
## before TechState/RunState/Sfx (which emit / also-subscribe to these same signals).
##
## Mutation reference (the complete set moved out of game.gd):
##   resource_changed → story.flags["has-<id>"]  (first-time-pickup, dialogue `has()`)
##   death            → story.counters.deaths
##   dissolved        → story.counters.dissolves  (full-clear return via the codex artifact)
##   boss_killed      → story.counters.boss_kills
##   run_ended        → story.counters.runs (+ meta.runs mirror) + story.counters.max_floor
##                      (max() of floor_reached — deepest floor ever, 2026-07-10); on victory
##                      also story.counters.full_clears + codex.shards (+ codex_shard_added)


func _ready() -> void:
	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.death.connect(_on_death)
	EventBus.dissolved.connect(_on_dissolved)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.run_ended.connect(_on_run_ended)


# --- EventBus handlers -------------------------------------------------------------

## First-time-pickup flags for the dialogue `has(<resource>)` conditions. Guarded on an
## empty state (resources can't change before a slot loads, but the guard mirrors the
## original game.gd handler exactly).
func _on_resource_changed(id: String, _old: float, new_amount: float, _reason: String) -> void:
	if SaveManager.state.is_empty():
		return
	StoryCore.record_pickup(SaveManager.state["story"], id, new_amount)


func _on_death(_source_id: String) -> void:
	StoryCore.record_death(SaveManager.state["story"])


func _on_dissolved() -> void:
	StoryCore.record_dissolve(SaveManager.state["story"])


func _on_boss_killed(_boss_id: String, _floor: int) -> void:
	StoryCore.record_boss_kill(SaveManager.state["story"])


## Run ended (win or die). Bumps the run counters (incl. max_floor from the signal's
## floor_reached), mirrors runs into meta (the slot-select readout), and — on victory
## (== full clear in the slice) — grants the codex shard. The day tick and the town
## swap stay in game.gd; the tech auto-solve moved to the TechState autoload.
func _on_run_ended(victory: bool, floor_reached: int, _stats: Dictionary) -> void:
	StoryCore.record_run_end(SaveManager.state["story"], victory, floor_reached)
	SaveManager.state["meta"]["runs"] = SaveManager.state["story"]["counters"]["runs"]
	if victory:
		grant_codex_shard()


# --- Public API (only where a call site already exists) ----------------------------

## Grant one codex shard and announce it. Used by the victory path above and by the F2
## cheat panel (both previously duplicated the codex+emit inline).
func grant_codex_shard() -> void:
	var total := StoryCore.grant_codex_shard(SaveManager.state["codex"])
	EventBus.codex_shard_added.emit(total)


## Raw-set a story flag (the F2 cascade escape hatch — cheat_panel routes here instead
## of poking the story dict directly). No-op on an empty state.
func set_flag(flag: String) -> void:
	if SaveManager.state.is_empty():
		return
	StoryCore.set_flag(SaveManager.state["story"], flag)
