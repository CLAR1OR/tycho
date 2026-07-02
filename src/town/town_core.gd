extends RefCounted
class_name TownCore
## Pure town logic (PRD §7.9, architecture-schemas.md §6): the day tick and the
## building helpers. The town itself is a plain data object living in the save
## (`{id, name, age, buildings: [{id, level}], map_pos}`); building definitions come
## from data/buildings/ via DataLoader. No autoloads, no engine state — everything
## here unit-tests headless. The scene layer (town.gd / game.gd) wires the results
## into Ledger + EventBus.


## How many levels of `building_id` the town has built (0 = not built).
static func building_level(town: Dictionary, building_id: String) -> int:
	for b: Dictionary in town.get("buildings", []):
		if str(b.get("id", "")) == building_id:
			return int(b.get("level", 0))
	return 0


## Pure update: return a NEW town dict with `building_id` at `level` (adds or bumps).
static func set_building(town: Dictionary, building_id: String, level: int) -> Dictionary:
	var out := town.duplicate(true)
	if not out.has("buildings"):
		out["buildings"] = []
	for b: Dictionary in out["buildings"]:
		if str(b.get("id", "")) == building_id:
			b["level"] = level
			return out
	out["buildings"].append({"id": building_id, "level": level})
	return out


## Cost of the NEXT level of a building given its current level ({} = maxed out).
## Levels are exactly 3 per the bible; levels[current] is the next one to buy.
static func next_level_cost(def: Dictionary, current_level: int) -> Dictionary:
	var levels: Array = def.get("levels", [])
	if current_level >= levels.size():
		return {}
	return (levels[current_level] as Dictionary).get("cost", {})


## The day tick (fires once per run end, 1 day = 1 run — locked decision): read the
## town's buildings against their definitions and return the produced resource
## deltas {resource_id: amount}. The caller writes them to the Ledger with reason
## "town-tick". Effect kinds handled: "produce" (+ "knowledge" as sugar for
## producing the knowledge resource); "multiplier"/"capability" land with the
## systems that consume them and are ignored here for now.
static func tick(town: Dictionary, building_defs: Dictionary) -> Dictionary:
	var out := {}
	for b: Dictionary in town.get("buildings", []):
		var id := str(b.get("id", ""))
		var level := int(b.get("level", 0))
		if not building_defs.has(id):
			push_error("TownCore.tick: town has unknown building \"%s\"" % id)
			continue
		var levels: Array = (building_defs[id] as Dictionary).get("levels", [])
		if level < 1 or level > levels.size():
			push_error("TownCore.tick: building \"%s\" at invalid level %d" % [id, level])
			continue
		for effect: Dictionary in (levels[level - 1] as Dictionary).get("effects", []):
			match str(effect.get("kind", "")):
				"produce":
					var res := str(effect.get("resource", ""))
					out[res] = float(out.get(res, 0.0)) + float(effect.get("per_day", 0.0))
				"knowledge":
					out["knowledge"] = float(out.get("knowledge", 0.0)) + float(effect.get("per_day", 0.0))
				_:
					pass  # multiplier/capability: consumed by later systems, not the tick
	return out
