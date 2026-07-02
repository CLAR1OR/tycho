extends Node
## RunState autoload — thin holder for the current run (godot-conventions.md
## autoload list). ALL progression logic lives in RunFlow (pure, tested); this node
## only keeps the live state dict and emits the EventBus run-lifecycle signals.
##
## In-run-only state (like Echoes later) belongs here, NOT in the save — a run that
## ends is gone (v1 resumes at floor start via autosave, handled by SaveManager's
## callers when that lands).

## The live RunFlow state dict; {} when not in a run.
var run: Dictionary = {}
## Which run this is (1-based, from the save's story counter) — for run_started.
var run_number: int = 0

# In-run-only state (PRD §7.5 — echoes die with the run, by design):
## Echo ids picked this run, in pick order (stackables may repeat).
var echoes: Array[String] = []
## How many echo offers were rolled (feeds the deterministic offer RNG).
var echo_offers_made: int = 0
## Player HP carried between rooms of the run; -1 = fresh (full).
var player_health: int = -1


func in_run() -> bool:
	return not run.is_empty() and not bool(run["over"])


func start_run(config: Dictionary, rng_seed: int, number: int) -> void:
	run = RunFlow.start(config, rng_seed)
	run_number = number
	echoes.clear()
	echo_offers_made = 0
	player_health = -1
	EventBus.run_started.emit(number)


func pick_echo(id: String) -> void:
	echoes.append(id)


func room_kind() -> String:
	return RunFlow.room_kind(run)


## Current room cleared. Boss rooms also announce the kill (boss_id comes from the
## room scene — placeholder ids until real bosses land). Emits run_ended when the
## run finishes. Returns true if the run is still going (caller loads the next room).
func room_cleared(boss_id: String = "") -> bool:
	if not in_run():
		push_error("RunState.room_cleared() outside a run")
		return false
	if room_kind() == RunFlow.KIND_BOSS:
		EventBus.boss_killed.emit(boss_id, RunFlow.floor_reached(run))
	run = RunFlow.advance(run)
	if bool(run["over"]):
		_end_run()
		return false
	return true


## The player died in the current room (no penalty — locked design).
func player_died(source_id: String = "") -> void:
	if not in_run():
		return
	EventBus.death.emit(source_id)
	run = RunFlow.fail(run)
	_end_run()


func _end_run() -> void:
	EventBus.run_ended.emit(
		bool(run["victory"]),
		RunFlow.floor_reached(run),
		{"rooms_this_floor": int(run["rooms_this_floor"]), "room": int(run["room"])})
