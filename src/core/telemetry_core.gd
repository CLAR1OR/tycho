extends RefCounted
class_name TelemetryCore
## Pure run-telemetry record shaping (analysis tooling, NOT the save system — see
## Telemetry.append's header for why this lives OUTSIDE user://saves/ and does not
## touch the no-mid-run-disk-write statistics invariant, design 2026-07-07).
##
## No engine clock/file IO here on purpose (godot-conventions rule 3): build_record
## takes plain inputs the caller (game.gd) already has to hand — a timestamp is
## deliberately NOT stamped here, duration_s already carries the timing signal, and
## a pure function calling Time would make this untestable/nondeterministic.

const OUTCOME_VICTORY := "victory"
const OUTCOME_DEATH := "death"
const OUTCOME_FORFEIT := "forfeit"
const OUTCOMES: Array[String] = [OUTCOME_VICTORY, OUTCOME_DEATH, OUTCOME_FORFEIT]


## Build one telemetry record. `echo_picks` is RunState.echoes (ids, pick order,
## stackables may repeat); `resource_deltas` is {resource_id: float} gained/lost
## over the run (the caller computes it — this class does no ledger math). Arrays/
## dicts are DUPLICATED so the record never aliases the caller's live containers.
static func build_record(run_number: int, slot: int, outcome: String, floor_reached: int,
		room_reached: int, duration_s: float, echo_picks: Array, resource_deltas: Dictionary) -> Dictionary:
	if not OUTCOMES.has(outcome):
		push_error("TelemetryCore.build_record: unknown outcome \"%s\"" % outcome)
	return {
		"run_number": run_number,
		"slot": slot,
		"outcome": outcome,
		"floor_reached": floor_reached,
		"room_reached": room_reached,
		"duration_s": duration_s,
		"echo_picks": echo_picks.duplicate(),
		"resource_deltas": resource_deltas.duplicate(),
	}


## One-line JSON serialization of a record (JSONL — one record per line on disk).
static func to_line(record: Dictionary) -> String:
	return JSON.stringify(record)
