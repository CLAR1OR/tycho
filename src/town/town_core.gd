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


## Is this building available to build, given researched tech? `unlocked_by` is a
## typed gate ({type: "tech", id}) or null (always available). Unknown gate types
## are LOCKED loudly — a typo must not silently open a building.
static func is_unlocked(def: Dictionary, researched_tech: Array) -> bool:
	var gate: Variant = def.get("unlocked_by")
	if gate == null:
		return true
	match str((gate as Dictionary).get("type", "")):
		"tech":
			return str((gate as Dictionary).get("id", "")) in researched_tech
		_:
			push_error("TownCore: building \"%s\" has unknown unlocked_by type \"%s\"" % [
				str(def.get("id", "?")), str((gate as Dictionary).get("type", ""))])
			return false


## Cost of the NEXT level of a building given its current level ({} = maxed out).
## Levels are exactly 3 per the bible; levels[current] is the next one to buy.
static func next_level_cost(def: Dictionary, current_level: int) -> Dictionary:
	var levels: Array = def.get("levels", [])
	if current_level >= levels.size():
		return {}
	return (levels[current_level] as Dictionary).get("cost", {})


# Food upkeep economy (design/food-upkeep.md, first impl 2026-07-05). These are
# PLACEHOLDER economy numbers to tune with the wider economy — NOT combat-feel
# values (no `# FEEL:` tag; that prefix is combat-feel only). Upkeep scales gently
# with town size (no population micro); the bonus is deliberately binary.
const UPKEEP_BASE: float = 2.0            # a town eats this much even with no buildings
const UPKEEP_PER_BUILDING: float = 1.0    # + this per built building
const WELL_FED_BONUS: float = 0.25        # +25% to all OTHER production when fed

# Room-scaled tick (HUMAN DECISION 2026-07-10 — amends the locked "1 day = 1 run"
# time model's MAGNITUDE, not its trigger): the tick still fires ONCE at run end
# (win or die; forfeit still ticks nothing) and the day COUNTER still advances 1 per
# run (fiction + dialogue gates untouched), but the tick's magnitude scales with
# rooms cleared. Rationale: a flat tick paid a room-1 suicide the same passive
# production as a 40-room clear — incentivizing suicide runs. PLACEHOLDER economy
# number: a "nominal day" = 10 cleared rooms.
const PER_ROOM_TICK: float = 0.1


## The day-tick magnitude for a finished run: rooms_cleared * PER_ROOM_TICK
## (0 rooms cleared → a zero tick; 10 rooms → exactly one nominal day).
static func run_tick_scale(rooms_cleared: int) -> float:
	return float(maxi(0, rooms_cleared)) * PER_ROOM_TICK


## The day tick (fires once per run end, 1 day = 1 run — locked decision; magnitude
## room-scaled since 2026-07-10, see PER_ROOM_TICK above): read the town's buildings
## against their definitions, apply the Food upkeep pass, and return
## `{"produced": {resource_id: amount}, "food_consumed": float, "well_fed": bool}`.
## `scale` multiplies ALL production AND the upkeep BEFORE the Well-Fed evaluation
## (well_fed is judged on the scaled numbers; the Ledger holds floats, fractional
## amounts are fine). The default 1.0 = one nominal day, so every per-day caller
## (HUD projections, existing tests) keeps its meaning unchanged.
## The caller writes `produced` to the Ledger (reason "town-tick") and spends
## `food_consumed` from Food (reason "upkeep") AFTER adding production — matching the
## "harvest comes in before the town eats" rule below.
##
## Tick order (architecture-schemas §6: produce → upkeep/status → status-modified
## totals): raw production first (incl. the Farm's Food), then upkeep decides
## Well-Fed, then the Well-Fed bonus multiplies every produced resource EXCEPT Food.
## Effect kinds handled in production: "produce" (+ "knowledge" as sugar for the
## knowledge resource); "multiplier"/"capability" land with their consumers.
##
## Well-Fed is a BONUS, never a penalty: short on food = just no bonus, no starvation
## state (mirrors the no-death-penalty philosophy). The town eats what it has even
## when short (consume = min(upkeep, available)); the balance can never go negative.
static func tick(town: Dictionary, building_defs: Dictionary, food_stock: float,
		scale: float = 1.0) -> Dictionary:
	# --- Raw production (incl. the Farm's Food) ---------------------------------
	var produced := {}
	var built := 0
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
		built += 1
		for effect: Dictionary in (levels[level - 1] as Dictionary).get("effects", []):
			match str(effect.get("kind", "")):
				"produce":
					var res := str(effect.get("resource", ""))
					produced[res] = float(produced.get(res, 0.0)) + float(effect.get("per_day", 0.0))
				"knowledge":
					produced["knowledge"] = float(produced.get("knowledge", 0.0)) + float(effect.get("per_day", 0.0))
				_:
					pass  # multiplier/capability: consumed by later systems, not the tick
	# --- Room-scale (2026-07-10): production AND upkeep both scale, BEFORE the
	# Well-Fed evaluation — the status is judged on the scaled numbers. ----------
	for res: String in produced:
		produced[res] = float(produced[res]) * scale
	# --- Upkeep pass: the harvest is in, now the town eats ----------------------
	var upkeep := (UPKEEP_BASE + UPKEEP_PER_BUILDING * float(built)) * scale
	var available := food_stock + float(produced.get("food", 0.0))
	var well_fed := available >= upkeep
	var food_consumed := minf(upkeep, available)  # eat what's there; never negative
	# --- Well-Fed bonus: +25% to every produced resource EXCEPT Food itself -----
	if well_fed:
		for res: String in produced:
			if res != "food":
				produced[res] = float(produced[res]) * (1.0 + WELL_FED_BONUS)
	return {"produced": produced, "food_consumed": food_consumed, "well_fed": well_fed}
