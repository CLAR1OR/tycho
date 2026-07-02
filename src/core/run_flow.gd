extends RefCounted
class_name RunFlow
## Pure run/floor/room progression logic (PRD §7.6 dungeon structure, §6.2 loop).
## No engine types, no autoloads, no clock — a run is a plain state Dictionary and
## every transition is a pure function returning a NEW dict, so all of it unit-tests
## headless. RunState (autoload) holds the live dict and emits the EventBus signals.
##
## Full game config is 5 floors x 6-10 rooms (PRD §7.6); the vertical slice passes a
## smaller config. The last room of every floor is the boss room. Room-TYPE variety
## (reprieve/upgrade rooms) and per-room layout choice land with dungeon generation —
## this is only the spine: where are we, what kind of room, what comes next.

const KIND_COMBAT := "combat"
const KIND_BOSS := "boss"


## Begin a run. `config`: {floors, rooms_min, rooms_max} (all int, all optional).
## `rng_seed` makes the whole run's structure reproducible (same seed → same shape).
static func start(config: Dictionary, rng_seed: int) -> Dictionary:
	var floors := int(config.get("floors", 5))
	var rooms_min := int(config.get("rooms_min", 6))
	var rooms_max := int(config.get("rooms_max", 10))
	return {
		"seed": rng_seed,
		"floors": maxi(1, floors),
		"rooms_min": maxi(1, rooms_min),
		"rooms_max": maxi(rooms_min, rooms_max),
		"floor": 1,
		"room": 1,  # 1-based index within the floor
		"rooms_this_floor": _rooms_for_floor(rng_seed, 1, rooms_min, rooms_max),
		"over": false,
		"victory": false,
	}


## What the CURRENT room is: the last room of every floor is its boss.
static func room_kind(state: Dictionary) -> String:
	return KIND_BOSS if int(state["room"]) >= int(state["rooms_this_floor"]) else KIND_COMBAT


## The current room was cleared — advance. Returns a NEW state: next room, next
## floor (after a boss), or over+victory (final boss down = full clear).
static func advance(state: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	if bool(out["over"]):
		push_error("RunFlow.advance() on a finished run")
		return out
	if int(out["room"]) < int(out["rooms_this_floor"]):
		out["room"] = int(out["room"]) + 1
	elif int(out["floor"]) < int(out["floors"]):
		out["floor"] = int(out["floor"]) + 1
		out["room"] = 1
		out["rooms_this_floor"] = _rooms_for_floor(
			int(out["seed"]), int(out["floor"]), int(out["rooms_min"]), int(out["rooms_max"]))
	else:
		out["over"] = true
		out["victory"] = true
	return out


## The player died — the run is over, not victorious (no penalty, per locked design;
## consequences beyond "back to town" are the caller's business, and there are none).
static func fail(state: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	out["over"] = true
	out["victory"] = false
	return out


static func floor_reached(state: Dictionary) -> int:
	return int(state["floor"])


## Deterministic per-floor room count: same (seed, floor) always gives the same
## answer, so a run's shape is fixed at start and survives save/resume later.
static func _rooms_for_floor(rng_seed: int, floor_num: int, rooms_min: int, rooms_max: int) -> int:
	if rooms_max <= rooms_min:
		return rooms_min
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rng_seed, floor_num])
	return rng.randi_range(rooms_min, rooms_max)
