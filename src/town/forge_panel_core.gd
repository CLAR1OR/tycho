extends RefCounted
class_name ForgePanelCore
## Pure helpers for Mara's Forge — "The anvil" screen (F2, human-picked 2026-07-08 via
## claude.ai/design, with the "no stat bars" amendment). The screen keeps asking two
## questions the strip + name-bar need answered; this class answers them without touching
## engine state (unit-tested headless). All cost/level math is delegated to WeaponCore —
## nothing is duplicated here.
##
## The current flat level is read at the call site with WeaponCore.flat_level(combat, id)
## and passed in as `level`, so this core never reaches into SaveManager.

## The refine track's next action for `def` at `level`:
##   {"kind": "refine", "cost": int, "to_level": int}  — one more level available
##   {"kind": "maxed",  "cost": 0,   "to_level": level} — the flat track is full
## Cost comes from WeaponCore.next_flat_cost (the weapon's flat.costs array).
static func refine_action(def: Dictionary, level: int) -> Dictionary:
	var cost := WeaponCore.next_flat_cost(def, level)
	if cost.is_empty():
		return {"kind": "maxed", "cost": 0, "to_level": level}
	return {"kind": "refine", "cost": int(cost["resonance-ore"]), "to_level": level + 1}


## The name-bar's "+N% DAMAGE" figure the flat track grants at `level` (e.g. L2 → 30.0),
## derived from WeaponCore.damage_mult (1 + damage_mult_per_level × level).
static func damage_bonus_pct(def: Dictionary, level: int) -> float:
	return (WeaponCore.damage_mult(def, level) - 1.0) * 100.0
