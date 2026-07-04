extends RefCounted
class_name StoryCore
## Pure story-bookkeeping logic (PRD §7.0/§7.11, architecture-schemas.md §1 "story"):
## every EventBus-driven mutation of the save's story section, extracted from game.gd
## so the routing lives in a thin StoryState autoload over this tested core. No engine
## singletons, no EventBus — StoryState owns the subscriptions and the signal emits.
##
## IN-PLACE by design (NOT the return-a-new-dict style of TownCore/DialogueCore): the
## counters/flags dicts are held live by call sites across many runs — the cheat panel
## grabs `state.story.counters` once and reads it after several simulate_run()s, and
## game.gd's old code mutated in place. Replacing the story dict would stale those refs
## (the exact hazard DialogueCore.mark_shown documents). So these helpers mutate the
## passed sub-dict in place and return only a value the caller needs (a bool / a total),
## never a fresh copy. Cross-section effects (the meta.runs mirror, the codex grant on
## victory) are applied by StoryState, which sees the whole state.


## First-time-pickup flag for the dialogue `has(<resource>)` vocabulary
## (act1-story-beats.md). Sets story.flags["has-<id>"] the first time a resource goes
## positive; returns true iff a NEW flag was set (idempotent afterward). Mutates story.
static func record_pickup(story: Dictionary, resource_id: String, new_amount: float) -> bool:
	if new_amount <= 0.0:
		return false
	var flags: Dictionary = story["flags"]
	var key := "has-" + resource_id
	if bool(flags.get(key, false)):
		return false
	flags[key] = true
	return true


## Player died in-run (EventBus.death) — bumps the deaths counter. No penalty rides
## this (locked design); it is pure bookkeeping. Mutates story.
static func record_death(story: Dictionary) -> void:
	var counters: Dictionary = story["counters"]
	counters["deaths"] = int(counters["deaths"]) + 1


## A boss was killed (EventBus.boss_killed) — bumps the boss_kills counter. Mutates
## story. (The codex-shard / full-clear reward rides run_ended, not this.)
static func record_boss_kill(story: Dictionary) -> void:
	var counters: Dictionary = story["counters"]
	counters["boss_kills"] = int(counters["boss_kills"]) + 1


## A run ended, win OR die (EventBus.run_ended, 1 day = 1 run) — always bumps runs;
## on victory also bumps full_clears (slice config is one floor, so victory == full
## clear — PRD §7.11). The meta.runs mirror + the codex shard are cross-section and
## are applied by StoryState. Mutates story.
static func record_run_end(story: Dictionary, victory: bool) -> void:
	var counters: Dictionary = story["counters"]
	counters["runs"] = int(counters["runs"]) + 1
	if victory:
		counters["full_clears"] = int(counters["full_clears"]) + 1


## Grant one codex shard (the full-clear reward — PRD §7.11 — and the F2 cheat).
## Lives in the codex section, not story; StoryState calls it on victory and emits
## codex_shard_added(total). Mutates codex; returns the new total.
static func grant_codex_shard(codex: Dictionary) -> int:
	var total := int(codex["shards"]) + 1
	codex["shards"] = total
	return total


## Raw-set a story flag true (the F2 cascade escape hatch — cheat_panel routes here).
## Mutates story.
static func set_flag(story: Dictionary, flag: String) -> void:
	(story["flags"] as Dictionary)[flag] = true
