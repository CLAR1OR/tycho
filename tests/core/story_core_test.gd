extends "res://tests/test_suite.gd"
## Tests StoryCore (src/core/story_core.gd) — the pure story-section bookkeeping the
## StoryState autoload rides on: the run/death/boss counters, the full-clear codex
## shard, the has-<resource> pickup flags, and the raw flag set. Everything here
## mutates the passed sub-dict IN PLACE (the deliberate design — see the core header);
## the tests assert on the SAME dict they passed in.


func _story() -> Dictionary:
	# A fresh story section, same shape SaveData.default_slot builds.
	return {
		"flags": {},
		"counters": {"runs": 0, "deaths": 0, "boss_kills": 0, "full_clears": 0},
		"seen": [],
		"talked_to": {},
		"dialogue_last": {},
		"arc_last": {},
	}


# --- Pickup flags ------------------------------------------------------------------

func test_pickup_sets_flag_first_time() -> void:
	var story := _story()
	var was_new := StoryCore.record_pickup(story, "resonance-ore", 3.0)
	check(was_new, "first positive pickup is a NEW flag")
	check(bool(story["flags"].get("has-resonance-ore", false)), "has-<id> flag set on the story")


func test_pickup_is_idempotent() -> void:
	var story := _story()
	StoryCore.record_pickup(story, "gold", 10.0)
	var second := StoryCore.record_pickup(story, "gold", 5.0)
	check(not second, "a resource already picked up returns false (no new flag)")
	check(story["flags"].size() == 1, "the flag is set exactly once")


func test_pickup_ignores_nonpositive() -> void:
	var story := _story()
	check(not StoryCore.record_pickup(story, "gold", 0.0), "zero amount is not a pickup")
	check(not StoryCore.record_pickup(story, "gold", -4.0), "a spend (negative) is not a pickup")
	check(story["flags"].is_empty(), "no flag set for non-positive amounts")


# --- Counters ----------------------------------------------------------------------

func test_death_increments() -> void:
	var story := _story()
	StoryCore.record_death(story)
	StoryCore.record_death(story)
	check_eq(int(story["counters"]["deaths"]), 2, "deaths counted")
	check_eq(int(story["counters"]["runs"]), 0, "death alone does not tick runs")


func test_boss_kill_increments() -> void:
	var story := _story()
	StoryCore.record_boss_kill(story)
	check_eq(int(story["counters"]["boss_kills"]), 1, "boss kill counted")


func test_run_end_bumps_runs_only_on_loss() -> void:
	var story := _story()
	StoryCore.record_run_end(story, false)
	check_eq(int(story["counters"]["runs"]), 1, "a lost run still ticks the day/runs")
	check_eq(int(story["counters"]["full_clears"]), 0, "a loss is not a full clear")


func test_run_end_victory_counts_full_clear() -> void:
	var story := _story()
	StoryCore.record_run_end(story, true)
	check_eq(int(story["counters"]["runs"]), 1, "victory ticks runs")
	check_eq(int(story["counters"]["full_clears"]), 1, "victory counts a full clear")


func test_counters_accumulate() -> void:
	var story := _story()
	StoryCore.record_run_end(story, true)
	StoryCore.record_run_end(story, false)
	StoryCore.record_run_end(story, true)
	check_eq(int(story["counters"]["runs"]), 3, "runs accumulate across win+loss")
	check_eq(int(story["counters"]["full_clears"]), 2, "only victories count as clears")


# --- Codex shard -------------------------------------------------------------------

func test_grant_codex_shard_returns_total() -> void:
	var codex := {"shards": 0}
	check_eq(StoryCore.grant_codex_shard(codex), 1, "first grant returns total 1")
	check_eq(StoryCore.grant_codex_shard(codex), 2, "second grant returns total 2")
	check_eq(int(codex["shards"]), 2, "the codex dict holds the running total")


# --- Raw flag set ------------------------------------------------------------------

func test_set_flag() -> void:
	var story := _story()
	StoryCore.set_flag(story, "b3")
	check(bool(story["flags"].get("b3", false)), "set_flag sets the flag true")


func test_mutates_in_place_not_a_copy() -> void:
	# The design contract: the passed dict IS the one mutated, so live refs held by
	# call sites (the cheat panel's counters ref) stay valid across calls.
	var story := _story()
	var counters_ref: Dictionary = story["counters"]
	StoryCore.record_run_end(story, true)
	check_eq(int(counters_ref["runs"]), 1, "a ref grabbed before the call sees the mutation")
