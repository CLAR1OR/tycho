extends RefCounted
class_name WaveCore
## Pure, deterministic wave composition for a combat room (design 2026-07-06 —
## "more enemies, in waves, like in Hades"). Given where a room sits in the run it
## returns a LIST of waves; each wave is an Array[String] of enemy TYPE IDS. The
## combat room maps those ids to scenes and spawns one wave at a time — the room only
## counts as cleared after the LAST wave falls (combat_room.gd).
##
## Kept pure (no engine types beyond the seeded RNG, no PackedScene) so it is unit
## tested under tests/core/ (godot-conventions rule 3). Deterministic in
## (floor_num, room_index, base_count, seed): the same room always composes the same
## waves, which is what lets the headless smoke force a known mix.
##
## Numbers here are PLACEHOLDERS flagged for human tuning (wave counts, wave sizes,
## per-type draw weights) — economy/feel dials, not code structure.

const TYPE_BRUTE := "brute"
const TYPE_SKIRMISHER := "skirmisher"
const TYPE_ARCHER := "archer"
const TYPE_SLAMMER := "slammer"      # AoE-after-windup (enemy_slammer.gd)
const TYPE_CHARGER := "charger"      # line-telegraph dash (enemy_charger.gd)

## Every id compose() can emit — the combat room must map each to a scene.
const TYPES: Array[String] = [TYPE_BRUTE, TYPE_SKIRMISHER, TYPE_ARCHER, TYPE_SLAMMER, TYPE_CHARGER]

# FEEL/placeholder: per-type draw weight (bigger = more common). Slammer + charger are
# lightly weighted so they season the mix from floor 1 without dominating it.
const TYPE_WEIGHTS := {
	TYPE_BRUTE: 3,
	TYPE_SKIRMISHER: 3,
	TYPE_ARCHER: 2,
	TYPE_SLAMMER: 1,
	TYPE_CHARGER: 1,
}

# FEEL/placeholder: how many sequential waves a room runs.
const MIN_WAVES := 2
const MAX_WAVES := 3
const THIRD_WAVE_AT := 4   # floor_num + room_index >= this → a room earns its 3rd wave


## The waves for a combat room. `base_count` is the room's enemy_count export (the old
## single-wave size); each wave grows so the TOTAL body count is well above the old
## one-wave rooms (that is the feedback). Returns Array of Array[String].
static func compose(floor_num: int, room_index: int, base_count: int, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "waves", floor_num, room_index])
	var count := wave_count(floor_num, room_index)
	var waves: Array = []
	for w in count:
		var size := wave_size(base_count, floor_num, room_index, w)
		var wave: Array[String] = []
		for _i in size:
			wave.append(_draw_type(rng))
		waves.append(wave)
	return waves


## Number of waves this room runs (2, or 3 once deep enough). Placeholder curve.
static func wave_count(floor_num: int, room_index: int) -> int:
	var n := MIN_WAVES
	if floor_num + room_index >= THIRD_WAVE_AT:
		n = MAX_WAVES
	return clampi(n, MIN_WAVES, MAX_WAVES)


## Size of wave `w` (0-based). Wave 0 == the old single-wave size; each later wave
## adds a body, so a room's total is roughly (waves) x the old count and rising.
static func wave_size(base_count: int, floor_num: int, room_index: int, w: int) -> int:
	return maxi(1, base_count + (floor_num - 1) + (room_index - 1) + w)


## Total bodies a room will spawn across all its waves — handy for tuning/tests.
static func total_enemies(floor_num: int, room_index: int, base_count: int) -> int:
	var total := 0
	for w in wave_count(floor_num, room_index):
		total += wave_size(base_count, floor_num, room_index, w)
	return total


# --- Helpers --------------------------------------------------------------------

## Weighted draw of one enemy type. Deterministic in the passed RNG. Type ids are
## visited in TYPES order so the weighted cut is stable across runs.
static func _draw_type(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for t in TYPES:
		total += float(TYPE_WEIGHTS[t])
	var roll := rng.randf() * total
	for t in TYPES:
		roll -= float(TYPE_WEIGHTS[t])
		if roll < 0.0:
			return t
	return TYPE_BRUTE  # unreachable barring float drift — a safe common default
