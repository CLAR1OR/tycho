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
	return _gate_open(def.get("unlocked_by"), researched_tech,
		"building \"%s\"" % str(def.get("id", "?")))


## Is `levels[level_index]` purchasable, given researched tech? Any level may carry
## its own `unlocked_by` gate (age-banded levels, town-economy.md 2026-07-10):
## in-band gates (Farm L3, Quarry L2) and band openers (Library L4). Missing gate =
## unlocked. FORWARD REFERENCES ARE INTENTIONAL: a gate naming a tech id with no
## data/tech/ file yet simply never unlocks until that node is authored (precedent:
## dormant etchings) — never a loud failure. Gates guard the PURCHASE only;
## already-built levels are grandfathered (the tick never checks gates).
static func is_level_unlocked(def: Dictionary, level_index: int, researched_tech: Array) -> bool:
	var levels: Array = def.get("levels", [])
	if level_index < 0 or level_index >= levels.size():
		return false
	return _gate_open((levels[level_index] as Dictionary).get("unlocked_by"), researched_tech,
		"building \"%s\" L%d" % [str(def.get("id", "?")), level_index + 1])


## The one gate evaluator both is_unlocked and is_level_unlocked share. null = open;
## {type: "tech", id} = open iff researched (an UNAUTHORED tech id is just "not
## researched" — the intentional dormant forward reference); an unknown gate TYPE is
## LOCKED loudly — a typo must not silently open anything.
static func _gate_open(gate: Variant, researched_tech: Array, where: String) -> bool:
	if gate == null:
		return true
	match str((gate as Dictionary).get("type", "")):
		"tech":
			return str((gate as Dictionary).get("id", "")) in researched_tech
		_:
			push_error("TownCore: %s has unknown unlocked_by type \"%s\"" % [
				where, str((gate as Dictionary).get("type", ""))])
			return false


## The building's display name at `current_level`: the def name, unless a BUILT level
## (≤ current) carries a `rename` — the highest built rename wins (band openers
## transform: Library → University once its Renaissance opener is raised).
static func display_name(def: Dictionary, current_level: int) -> String:
	var name := str(def.get("name", def.get("id", "?")))
	var levels: Array = def.get("levels", [])
	for i in mini(current_level, levels.size()):
		var rename := str((levels[i] as Dictionary).get("rename", ""))
		if not rename.is_empty():
			name = rename
	return name


## Cost of the NEXT level of a building given its current level ({} = maxed out).
## Levels are AGE-BANDED (town-economy.md): the array grows as later ages are
## authored; levels[current] is the next one to buy.
static func next_level_cost(def: Dictionary, current_level: int) -> Dictionary:
	var levels: Array = def.get("levels", [])
	if current_level >= levels.size():
		return {}
	return (levels[current_level] as Dictionary).get("cost", {})


## Sum `key` across all built buildings' CURRENT-level capability effects (levels are
## REPLACE-semantics — only the current level counts). Generic: the Cathedral's
## `shard_value_add` reads through this; future capability numbers need no new code.
static func capability_value(town: Dictionary, building_defs: Dictionary, key: String) -> float:
	var total := 0.0
	for b: Dictionary in town.get("buildings", []):
		var id := str(b.get("id", ""))
		var level := int(b.get("level", 0))
		if not building_defs.has(id):
			continue
		var levels: Array = (building_defs[id] as Dictionary).get("levels", [])
		if level < 1 or level > levels.size():
			continue
		for effect: Dictionary in (levels[level - 1] as Dictionary).get("effects", []):
			if str(effect.get("kind", "")) == "capability" and effect.has(key):
				total += float(effect[key])
	return total


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

# Market auto-sell (design/town-economy.md, 2026-07-10). PLACEHOLDER economy number:
# the keep-buffer is this many NOMINAL (scale-1.0) days of upkeep — a stock target,
# independent of run length. Food above it sells on the tick at the Market's
# current-level `sell_food_rate` (data, data/buildings/market.json).
const MARKET_KEEP_BUFFER_DAYS: float = 2.0


## The day-tick magnitude for a finished run: rooms_cleared * PER_ROOM_TICK
## (0 rooms cleared → a zero tick; 10 rooms → exactly one nominal day).
static func run_tick_scale(rooms_cleared: int) -> float:
	return float(maxi(0, rooms_cleared)) * PER_ROOM_TICK


## The day tick (fires once per run end, 1 day = 1 run — locked decision; magnitude
## room-scaled since 2026-07-10, see PER_ROOM_TICK above): read the town's buildings
## against their definitions, apply the Food upkeep pass, and return
## `{"produced": {resource_id: amount}, "food_consumed": float, "well_fed": bool,
##   "food_sold": float, "gold_from_sale": float}` — the last two are STABLE keys,
## 0.0 whenever there is no Market / no surplus (Market auto-sell, town-economy.md).
## `scale` multiplies ALL production AND the upkeep BEFORE the Well-Fed evaluation
## (well_fed is judged on the scaled numbers; the Ledger holds floats, fractional
## amounts are fine). The default 1.0 = one nominal day, so every per-day caller
## (HUD projections, existing tests) keeps its meaning unchanged.
## The caller writes `produced` to the Ledger (reason "town-tick"), spends
## `food_consumed` from Food (reason "upkeep") AFTER adding production — matching the
## "harvest comes in before the town eats" rule below — then applies the auto-sell
## (spend food_sold / add gold_from_sale, reason "market-sale").
##
## Tick order (architecture-schemas §6): raw production first (incl. the Farm's
## Food), then each built building's CURRENT level's `multiplier` effects fold
## multiplicatively into `produced` (a multiplier on a resource nothing produced is
## a no-op — levels stay REPLACE-semantics), then the room-scale, then upkeep decides
## Well-Fed, then the Well-Fed bonus multiplies every produced resource EXCEPT Food,
## then the Market sells the Food stock above its keep-buffer.
## Effect kinds handled here: "produce" (+ "knowledge" as sugar for the knowledge
## resource), "multiplier", the Market's "capability" rate; other capabilities are
## consumed by their own systems, not the tick.
##
## Well-Fed is a BONUS, never a penalty: short on food = just no bonus, no starvation
## state (mirrors the no-death-penalty philosophy). The town eats what it has even
## when short (consume = min(upkeep, available)); the balance can never go negative.
static func tick(town: Dictionary, building_defs: Dictionary, food_stock: float,
		scale: float = 1.0) -> Dictionary:
	# --- Raw production (incl. the Farm's Food) ---------------------------------
	var produced := {}
	var built := 0
	var current_levels: Array = []  # each built building's current level dict (for pass 2)
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
		current_levels.append(levels[level - 1])
		for effect: Dictionary in (levels[level - 1] as Dictionary).get("effects", []):
			match str(effect.get("kind", "")):
				"produce":
					var res := str(effect.get("resource", ""))
					produced[res] = float(produced.get(res, 0.0)) + float(effect.get("per_day", 0.0))
				"knowledge":
					produced["knowledge"] = float(produced.get("knowledge", 0.0)) + float(effect.get("per_day", 0.0))
				_:
					pass  # multiplier folds in pass 2; capability with its consumer
	# --- Multipliers (town-economy.md, 2026-07-10): the Library's +% Knowledge, the
	# Mill's +% Food/Stone. Fold multiplicatively into what pass 1 produced; a
	# resource nothing produced stays absent (no-op). --------------------------------
	for lvl: Dictionary in current_levels:
		for effect: Dictionary in lvl.get("effects", []):
			if str(effect.get("kind", "")) == "multiplier":
				var res := str(effect.get("resource", ""))
				if produced.has(res):
					produced[res] = float(produced[res]) * float(effect.get("mult", 1.0))
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
	# --- Market auto-sell (town-economy.md, 2026-07-10): the town eats first, then
	# the Market sells the stock above the keep-buffer (MARKET_KEEP_BUFFER_DAYS ×
	# NOMINAL upkeep — a stock target independent of run length) at the current
	# level's data rate. Stable return keys, 0.0 when no Market / no surplus. -----
	var food_sold := 0.0
	var gold_from_sale := 0.0
	var market_level := building_level(town, "market")
	if market_level >= 1 and building_defs.has("market"):
		var market_caps := capability_effect(building_defs["market"], market_level, "market")
		var rate := float(market_caps.get("sell_food_rate", 0.0))
		if rate > 0.0:
			var buffer := MARKET_KEEP_BUFFER_DAYS * (UPKEEP_BASE + UPKEEP_PER_BUILDING * float(built))
			var surplus := food_stock + float(produced.get("food", 0.0)) - food_consumed - buffer
			if surplus > 0.0:
				food_sold = surplus
				gold_from_sale = surplus * rate
	return {"produced": produced, "food_consumed": food_consumed, "well_fed": well_fed,
		"food_sold": food_sold, "gold_from_sale": gold_from_sale}


## The capability effect dict with `id == cap_id` on `def`'s current level ({} when
## unbuilt / out of range / absent). Levels REPLACE — only the current level's
## capability counts (the Market's rates, town-economy.md).
static func capability_effect(def: Dictionary, level: int, cap_id: String) -> Dictionary:
	var levels: Array = def.get("levels", [])
	if level < 1 or level > levels.size():
		return {}
	for effect: Dictionary in (levels[level - 1] as Dictionary).get("effects", []):
		if str(effect.get("kind", "")) == "capability" and str(effect.get("id", "")) == cap_id:
			return effect
	return {}
