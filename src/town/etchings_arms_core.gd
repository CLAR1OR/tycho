extends RefCounted
class_name EtchingsArmsCore
## Pure helpers for the etchings "arms" panel (E1, human-picked 2026-07-08 via
## claude.ai/design). The panel shows Tycho's four marks and nothing else (the no-swap
## rule) — this class answers the two questions the screen keeps asking: which ability a
## site displays, and what its menu action is. Layered on EtchingsCore's predicates (no
## cost math is duplicated here). No engine state — unit-tested headless.

## Which ability a slot's mark displays: the EQUIPPED ability when one is equipped, else
## the slot's STARTER (so an old save with e.g. Bolt equipped on RMB renders Bolt, and a
## fresh save shows the dormant starter mark waiting to be awakened). The dash site ("spc")
## is innate and handled by the panel — it never routes through here.
static func displayed_ability(slot: String, etchings: Dictionary, starters: Dictionary) -> String:
	var equipped := str((etchings.get("slots", {}) as Dictionary).get(slot, ""))
	if not equipped.is_empty():
		return equipped
	return str(starters.get(slot, ""))


## The menu's action for `def` given the current save: awaken (dormant → L1), deepen
## (L1..L2 → next), or mastered (at MAX). `cost` is the Dust price (-1 when mastered);
## `to_level` is the level the action would reach. Costs come from EtchingsCore.learn_cost.
static func menu_action(def: Dictionary, etchings: Dictionary) -> Dictionary:
	var id := str(def.get("id", ""))
	var level := EtchingsCore.level_of(etchings, id)
	if level >= EtchingsCore.MAX_LEVEL:
		return {"kind": "mastered", "cost": -1, "to_level": EtchingsCore.MAX_LEVEL}
	var cost := EtchingsCore.learn_cost(def, level)
	if level <= 0:
		return {"kind": "awaken", "cost": cost, "to_level": 1}
	return {"kind": "deepen", "cost": cost, "to_level": level + 1}
