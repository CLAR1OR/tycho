extends "res://tests/test_suite.gd"
## Tests UnlocksCore (src/core/unlocks_core.gd) — the story-flag → system mapping
## and is_unlocked, over synthetic save states.


func _state(flags: Dictionary = {}) -> Dictionary:
	return {"story": {"flags": flags}}


func test_mapping_is_the_cascade() -> void:
	check_eq(UnlocksCore.SYSTEMS["weapons"], "b1", "weapons <- B1 (Mara and the ore)")
	check_eq(UnlocksCore.SYSTEMS["etchings"], "b2", "etchings <- B2 (Thomas; dormant in v1)")
	check_eq(UnlocksCore.SYSTEMS["tech"], "b3", "tech <- B3 (Sophia cracks the shards)")
	check_eq(UnlocksCore.SYSTEMS["building"], "b4", "building <- B4 (Herzog opens the ledger)")


func test_locked_until_flag_set() -> void:
	var fresh := _state()
	check(not UnlocksCore.is_unlocked(fresh, "weapons"), "fresh save: forge locked")
	check(not UnlocksCore.is_unlocked(fresh, "tech"), "fresh save: desk locked")
	check(not UnlocksCore.is_unlocked(fresh, "building"), "fresh save: build locked")
	check(not UnlocksCore.is_unlocked(fresh, "etchings"), "fresh save: etchings locked")


func test_unlock_transitions() -> void:
	check(UnlocksCore.is_unlocked(_state({"b1": true}), "weapons"), "B1 opens weapons")
	check(UnlocksCore.is_unlocked(_state({"b3": true}), "tech"), "B3 opens tech")
	check(UnlocksCore.is_unlocked(_state({"b4": true}), "building"), "B4 opens building")
	# One flag opens exactly one system — the cascade is one-at-a-time.
	var only_b1 := _state({"b1": true})
	check(not UnlocksCore.is_unlocked(only_b1, "tech"), "B1 alone leaves tech shut")
	check(not UnlocksCore.is_unlocked(only_b1, "building"), "B1 alone leaves building shut")


func test_false_flag_value_is_locked() -> void:
	# A flag present but explicitly false must read as locked (defensive vs. bad data).
	check(not UnlocksCore.is_unlocked(_state({"b1": false}), "weapons"),
		"flag set to false is still locked")


func test_unknown_system_is_false() -> void:
	# A typo must never silently open a facility — false, and loud (push_error).
	check(not UnlocksCore.is_unlocked(_state({"b1": true}), "wepons"),
		"unknown system id resolves locked")


func test_missing_story_is_locked() -> void:
	# A malformed/empty save state must not crash and must stay locked.
	check(not UnlocksCore.is_unlocked({}, "weapons"), "empty state: locked, no crash")
	check(not UnlocksCore.is_unlocked({"story": {}}, "tech"), "story without flags: locked")
