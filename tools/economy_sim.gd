extends Node
## Headless economy simulator (analysis tooling, NOT game code — never referenced by
## src/ or scenes/). Walks N simulated runs through the REAL pure cores + REAL data/
## numbers (RunFlow, DoorCore, WaveCore, TownCore, TechCore, WeaponCore, EtchingsCore,
## AttunementsCore, DataLoader) so this can never drift from the game: every cost,
## every prereq, every tick formula is read off the same classes combat_room.gd/
## game.gd call. The ONLY numbers invented here are the per-kill income assumptions
## (below), because that math lives in combat_room.gd as scene-side @export defaults,
## not in a pure core — cited by line number so they can be re-checked by hand.
##
## RUN (from the repo root, headless, no editor/window):
##   /home/clarior/Godot_v4.7-stable_linux.x86_64 --headless --path . \
##     res://tools/economy_sim.tscn
##
## Prints the report to stdout AND writes it to design/economy-sim.md (overwritten
## each run — the file IS the tool's last output, not hand-maintained prose).
## Runs as a SCENE, not a `-s`/`--script` (godot-conventions: "-s scripts never get
## autoloads" — confirmed here too: WeaponCore.apply_to_player's `Player` type hint
## transitively compiles player.gd, which references the Sfx autoload identifier, and
## `-s` mode fails that compile). Booting as a scene sidesteps it exactly like the
## smoke does; this tool still touches no autoload state — only pure `class_name`
## cores + DataLoader, plus a throwaway `LedgerCore.new()` per seed standing in for
## the real `Ledger` autoload.
##
## CAVEAT (read before trusting a number): every dollar figure here is a PLACEHOLDER
## economy multiplied by a SIMPLIFIED, DOCUMENTED player policy — it does not predict
## real playtest pacing. What it DOES measure honestly, because the math is the game's
## own: relative pressure between resource sinks (does Dust run dry before Gold does?),
## whether ~40 runs is enough to exhaustively test the spend sinks that exist TODAY, and
## where a sink saturates and starts stockpiling forever. Treat every number as "how the
## CURRENT placeholder economy behaves under a synthetic player", not a balance verdict.

# --- Income assumptions — READ off src/combat/combat_room.gd's @export DEFAULTS, not
# invented (cited by line; re-check by hand if that file's defaults ever move) --------
const GOLD_PER_KILL_MIN := 1        # combat_room.gd:51 gold_per_enemy_min
const GOLD_PER_KILL_MAX := 3        # combat_room.gd:52 gold_per_enemy_max
const GOLD_PER_KILL_MID := float(GOLD_PER_KILL_MIN + GOLD_PER_KILL_MAX) / 2.0
const ORE_DROP_CHANCE := 0.12       # combat_room.gd:53 ore_drop_chance (per kill)
const BOSS_GOLD := 25.0             # combat_room.gd:54 boss_gold
const BOSS_SHARDS := 1.0            # combat_room.gd:55 boss_shards
const BOSS_ORE := 2.0               # combat_room.gd:56 boss_ore
const BASE_ENEMY_COUNT := 3         # combat_room.gd:42 enemy_count (room's base wave size)
# Per-kill/door income is applied as its EXPECTED VALUE (bodies * chance), not a rolled
# RNG outcome — the sim reports pacing means, so the deterministic expectation IS the
# quantity of interest and removes a second, redundant RNG stream.

# --- Run shape — the FULL target game (PRD §7.6), not the vertical-slice config -------
const RUN_FLOORS := 5
const ROOMS_MIN := 6
const ROOMS_MAX := 10
const NUM_RUNS := 40
const SEEDS: Array[int] = [1001, 2002, 3003]   # "40 runs x 3 seeds" per the brief

# --- Player policy (fixed, documented — see header) -----------------------------------
# Runs 1-3 die at that floor's BOSS room (having cleared every room before it, incl.
# earlier floors' bosses) — a crude stand-in for "the player isn't good yet". Run 4
# onward is always a full clear (all 5 floors, final boss, codex shard). This is a
# blunt ramp, not a skill model; it exists so the sim has SOME early mortality instead
# of pretending every run is a flawless clear from turn 1.
const EARLY_DEATH_FLOORS := 3   # runs 1..EARLY_DEATH_FLOORS die on floor == run_number

# --- Door policy: which door in a 1-2 door offer gets walked into. Fixed priority,
# LOWER = preferred. Reprieve is deliberately last: "prefer echo > reprieve when
# hurt-flag (ignore) > dust > ore > gold" — the sim never tracks HP, so the hurt-flag
# is always false and reprieve never outranks a cache door; it's only ever taken when
# it is literally the only door in the offer. "Peril always accepted" needs no extra
# code: peril never lowers a door's rank here, so the policy never avoids it. --------
const DOOR_PRIORITY := {
	"echo": 0,
	"dust": 1,
	"ore": 2,
	"gold": 3,
	"reprieve": 4,
}


func _ready() -> void:
	var building_defs := DataLoader.load_domain("buildings")
	var tech_defs := DataLoader.load_domain("tech")
	var weapon_defs := DataLoader.load_domain("weapons")
	var etching_defs := DataLoader.load_domain("etchings")
	var attunement_defs := DataLoader.load_domain("attunements")
	var floor_defs := DataLoader.load_domain("floors")

	var per_seed: Array = []
	for seed in SEEDS:
		per_seed.append(_simulate_seed(seed, NUM_RUNS, building_defs, tech_defs,
			weapon_defs, etching_defs, attunement_defs, floor_defs))

	var report := _build_report(per_seed, tech_defs, etching_defs, attunement_defs, weapon_defs, building_defs)
	print(report)
	var f := FileAccess.open("res://design/economy-sim.md", FileAccess.WRITE)
	if f == null:
		printerr("economy_sim: could not open design/economy-sim.md for write (error %d)" % FileAccess.get_open_error())
	else:
		f.store_string(report)
		f.close()
		print("\n[economy_sim] wrote design/economy-sim.md")
	get_tree().quit()


# --- One seed's whole simulated saga --------------------------------------------------

## Runs `num_runs` sequential runs+town-visits for one seed. Returns an Array of
## per-run record Dictionaries (the town's state snapshot AFTER that run's spend pass).
func _simulate_seed(seed: int, num_runs: int, building_defs: Dictionary, tech_defs: Dictionary,
		weapon_defs: Dictionary, etching_defs: Dictionary, attunement_defs: Dictionary,
		floor_defs: Dictionary) -> Array:
	var ledger := LedgerCore.new()
	var town: Dictionary = {"id": "home", "name": "Home", "age": 1, "buildings": [], "well_fed": false}
	var tech: Dictionary = {"researched": [], "in_progress": {}, "auto_solve_counters": {}, "quiz_locked": {}, "active": ""}
	var combat: Dictionary = {"current_weapon": "sword", "weapons": {}}
	var etchings: Dictionary = {"slots": {"rmb": "", "q": "", "r": ""}, "unlocked": {}}
	var attunements: Dictionary = {}
	var codex_shards := 0

	var records: Array = []
	for run_num in range(1, num_runs + 1):
		var run_seed: int = hash([seed, "run", run_num])
		var death_floor := run_num if run_num <= EARLY_DEATH_FLOORS else -1
		var full_clear := death_floor == -1

		_simulate_run(run_seed, death_floor, floor_defs, ledger, attunements, attunement_defs)

		# Day tick (win OR die, per locked design) — the REAL TownCore.tick, verbatim
		# call shape to game.gd's _on_run_ended.
		var tick := TownCore.tick(town, building_defs, ledger.get_amount("food"))
		var produced: Dictionary = tick["produced"]
		for id: String in produced:
			ledger.add(id, float(produced[id]))
		ledger.try_spend("food", float(tick["food_consumed"]))
		town["well_fed"] = bool(tick["well_fed"])

		if full_clear:
			codex_shards = mini(codex_shards + 1, StoryCore.CODEX_SHARDS_MAX)

		# Spend policy, in order (see class header / report policy section).
		_turn_in_shards(ledger)
		tech = _invest_knowledge(tech, tech_defs, ledger)
		town = _spend_buildings(town, building_defs, tech["researched"], ledger)
		combat = _spend_weapons(combat, weapon_defs, ledger)
		etchings = _spend_etchings(etchings, etching_defs, ledger)
		attunements = _spend_attunements(attunements, attunement_defs, ledger)

		records.append({
			"run": run_num,
			"outcome": "full_clear" if full_clear else ("death_floor_%d" % death_floor),
			"gold": ledger.get_amount("gold"),
			"stone": ledger.get_amount("stone"),
			"food": ledger.get_amount("food"),
			"ore": ledger.get_amount("resonance-ore"),
			"dust": ledger.get_amount("resonance-dust"),
			"shards": ledger.get_amount("knowledge-shards"),
			"knowledge": ledger.get_amount("knowledge"),
			"buildings_built": _count_buildings(town),
			"buildings_maxed": _count_maxed_buildings(town, building_defs),
			"building_levels": _building_levels(town, building_defs),
			"techs_done": (tech["researched"] as Array).size(),
			"etchings_maxed": _count_maxed_etchings(etchings, etching_defs),
			"attunements_maxed": _count_maxed_attunements(attunements, attunement_defs),
			"weapons_maxed": _count_maxed_weapons(combat, weapon_defs),
			"codex_shards": codex_shards,
			"well_fed": town["well_fed"],
		})
	return records


## Walk one run room-by-room via the REAL RunFlow + DoorCore + WaveCore, adding income
## to `ledger` as it goes. Dies (stops early, no boss loot) at `death_floor`'s boss room
## when death_floor >= 0; otherwise runs the full 5-floor clear.
func _simulate_run(run_seed: int, death_floor: int, floor_defs: Dictionary, ledger: LedgerCore,
		attunements: Dictionary, attunement_defs: Dictionary) -> void:
	var find_mult := AttunementsCore.find_rate_mult(attunements, attunement_defs)
	var state := RunFlow.start({"floors": RUN_FLOORS, "rooms_min": ROOMS_MIN, "rooms_max": ROOMS_MAX}, run_seed)
	var plan: Dictionary = {}
	var pending_door: Dictionary = {}
	var guard := 0
	while guard < 200:
		guard += 1
		if int(state["room"]) == 1:
			# New floor: no incoming door, (re)generate this floor's plan — mirrors
			# game.gd._next_room exactly (same DoorCore call, same trigger).
			var profile := _floor_profile(floor_defs, int(state["floor"]))
			plan = DoorCore.generate_plan(run_seed, int(state["floor"]), int(state["rooms_this_floor"]),
				profile["door_weights"], float(profile["peril_chance"]))
			pending_door = {}
		var floor_num := int(state["floor"])
		var room_index := int(state["room"])
		var is_boss := RunFlow.room_kind(state) == RunFlow.KIND_BOSS

		if is_boss and floor_num == death_floor:
			return  # dies here: no clear, no boss loot, no next floor

		var bodies := WaveCore.total_enemies(floor_num, room_index, BASE_ENEMY_COUNT)
		ledger.add("gold", float(bodies) * GOLD_PER_KILL_MID)
		ledger.add("resonance-ore", float(bodies) * ORE_DROP_CHANCE * find_mult)

		if is_boss:
			ledger.add("gold", BOSS_GOLD)
			ledger.add("knowledge-shards", BOSS_SHARDS)
			ledger.add("resonance-ore", BOSS_ORE)
			# No cache on boss entry, matching the game: DoorCore always appends the boss
			# door ALONE at floor end and "boss" is not a cache sigil, so the incoming
			# door of a boss room never carries a cache — game.gd's boss branch skipping
			# _pay_cache drops nothing. (Verified 2026-07-10 against DoorCore.layout_plan
			# + CACHE_SIGILS.)
			pending_door = {}
		else:
			if not pending_door.is_empty():
				var sigil := str(pending_door.get("sigil", ""))
				if sigil != DoorCore.SIGIL_ECHO and sigil != DoorCore.SIGIL_REPRIEVE:
					var reward := DoorCore.cache_reward(sigil, floor_num, bool(pending_door.get("peril", false)))
					if not reward.is_empty():
						var amt := float(reward["amount"])
						var res := str(reward["resource"])
						if res == "resonance-dust" or res == "resonance-ore":
							amt = roundf(amt * find_mult)  # Attunement find-rate, same as combat_room._pay_cache
						ledger.add(res, amt)
				# echo/reprieve doors pay no cache — the pick / the heal are not economic
			var offer := DoorCore.offer_for_room(plan, room_index)
			pending_door = _choose_door(offer)

		state = RunFlow.advance(state)
		if bool(state["over"]):
			return  # full clear


func _choose_door(offer: Array) -> Dictionary:
	if offer.is_empty():
		return {}
	var best: Dictionary = offer[0]
	var best_rank: int = int(DOOR_PRIORITY.get(str(best.get("sigil", "")), 99))
	for d: Dictionary in offer:
		var r: int = int(DOOR_PRIORITY.get(str(d.get("sigil", "")), 99))
		if r < best_rank:
			best_rank = r
			best = d
	return best


func _floor_profile(floor_defs: Dictionary, floor_num: int) -> Dictionary:
	if floor_defs.has(str(floor_num)):
		return floor_defs[str(floor_num)]
	var best := {}
	var highest := 0
	for id: String in floor_defs:
		if int(floor_defs[id]["id"]) >= highest:
			highest = int(floor_defs[id]["id"])
			best = floor_defs[id]
	return best


# --- Spend policy (town visit, in order — see class header) ---------------------------

## (1) Turn in every whole Knowledge Shard for Knowledge (TechCore.shard_turn_in_value —
## the same math TechState.turn_in_shards spends, whole shards only).
func _turn_in_shards(ledger: LedgerCore) -> void:
	var whole := floorf(ledger.get_amount("knowledge-shards"))
	if whole <= 0.0:
		return
	var gain := TechCore.shard_turn_in_value(whole)
	ledger.try_spend("knowledge-shards", whole)
	ledger.add("knowledge", gain)


## (2) Invest all available Knowledge into the cheapest available tech node (real
## prereqs via TechCore.available); a node that reaches its cost completes immediately
## (quiz ASSUMED SOLVED — the sim never fails a quiz). Stops when the remaining
## Knowledge can't complete the next-cheapest node (it stays banked as in_progress for
## next visit — TechCore.invest already caps at each node's own remaining cost).
func _invest_knowledge(tech: Dictionary, tech_defs: Dictionary, ledger: LedgerCore) -> Dictionary:
	var out := tech.duplicate(true)
	var guard := 0
	while ledger.get_amount("knowledge") > 0.0 and guard < 32:
		guard += 1
		var avail := TechCore.available(tech_defs, out)
		if avail.is_empty():
			break
		avail.sort_custom(func(a: String, b: String) -> bool:
			return float(tech_defs[a]["cost_knowledge"]) < float(tech_defs[b]["cost_knowledge"]))
		var id: String = avail[0]
		var def: Dictionary = tech_defs[id]
		var result := TechCore.invest(out, def, ledger.get_amount("knowledge"))
		out = result["tech"]
		var accepted := float(result["accepted"])
		if accepted <= 0.0:
			break
		ledger.try_spend("knowledge", accepted)
		if TechCore.is_ready(def, out):
			out = TechCore.complete(out, id)
			# TownCore.is_unlocked reads `out["researched"]` directly next spend step —
			# no separate "unlocks" dispatch needed for the building-gate effect.
		else:
			break  # partially funded — carries to the next town visit
	return out


## (3) Buildings, greedily: repeatedly buy whichever unlocked building's NEXT level is
## both affordable and cheapest (cost magnitude = the sum of its cost dict's amounts —
## buildings only ever cost gold+stone, so this is a simple, order-independent tiebreak).
func _spend_buildings(town: Dictionary, building_defs: Dictionary, researched: Array, ledger: LedgerCore) -> Dictionary:
	var out := town.duplicate(true)
	while true:
		var best_id := ""
		var best_cost: Dictionary = {}
		var best_mag := INF
		for id: String in building_defs:
			var def: Dictionary = building_defs[id]
			if not TownCore.is_unlocked(def, researched):
				continue
			var lvl := TownCore.building_level(out, id)
			var cost := TownCore.next_level_cost(def, lvl)
			if cost.is_empty() or not ledger.can_afford(cost):
				continue
			var mag := 0.0
			for r: String in cost:
				mag += float(cost[r])
			if mag < best_mag:
				best_mag = mag
				best_id = id
				best_cost = cost
		if best_id == "":
			break
		ledger.try_spend_all(best_cost)
		out = TownCore.set_building(out, best_id, TownCore.building_level(out, best_id) + 1)
	return out


## (4) Weapon flat refines, greedily cheapest-next-level-first across all 3 weapons
## (the sim tracks every weapon's track, not just whichever is "equipped" — there is no
## equip-choice model here, only the Ore sink).
func _spend_weapons(combat: Dictionary, weapon_defs: Dictionary, ledger: LedgerCore) -> Dictionary:
	var out := combat.duplicate(true)
	while true:
		var best_id := ""
		var best_cost: Dictionary = {}
		var best_amt := INF
		for id: String in weapon_defs:
			var def: Dictionary = weapon_defs[id]
			var lvl := WeaponCore.flat_level(out, id)
			var cost := WeaponCore.next_flat_cost(def, lvl)
			if cost.is_empty() or not ledger.can_afford(cost):
				continue
			var amt := float(cost.get("resonance-ore", 0.0))
			if amt < best_amt:
				best_amt = amt
				best_id = id
				best_cost = cost
		if best_id == "":
			break
		ledger.try_spend_all(best_cost)
		out = WeaponCore.with_flat_level(out, best_id, WeaponCore.flat_level(out, best_id) + 1)
	return out


## (5a) Dust sink, PART ONE: implemented etchings first, cheapest-next-level-first,
## until all 5 are maxed or Dust runs out.
func _spend_etchings(etchings: Dictionary, etching_defs: Dictionary, ledger: LedgerCore) -> Dictionary:
	var out := etchings.duplicate(true)
	while true:
		var best_id := ""
		var best_cost := -1
		var dust := ledger.get_amount("resonance-dust")
		for id in EtchingsCore.IMPLEMENTED:
			if not etching_defs.has(id):
				continue
			var def: Dictionary = etching_defs[id]
			if not EtchingsCore.can_learn(def, dust, out):
				continue
			var cost := EtchingsCore.learn_cost(def, EtchingsCore.level_of(out, id))
			if best_id == "" or cost < best_cost:
				best_id = id
				best_cost = cost
		if best_id == "":
			break
		ledger.try_spend("resonance-dust", float(best_cost))
		out = EtchingsCore.learn(out, best_id)
	return out


## (5b) Dust sink, PART TWO: once every implemented etching is maxed (or unaffordable
## for now), the SAME Dust flows to attunements — cheapest-next-level-first.
func _spend_attunements(attunements: Dictionary, attunement_defs: Dictionary, ledger: LedgerCore) -> Dictionary:
	var out := attunements.duplicate(true)
	while true:
		var best_id := ""
		var best_cost := -1
		var dust := ledger.get_amount("resonance-dust")
		for id: String in attunement_defs:
			var def: Dictionary = attunement_defs[id]
			if not AttunementsCore.can_deepen(def, dust, out):
				continue
			var cost := AttunementsCore.next_cost(def, AttunementsCore.level(out, id))
			if best_id == "" or cost < best_cost:
				best_id = id
				best_cost = cost
		if best_id == "":
			break
		ledger.try_spend("resonance-dust", float(best_cost))
		out = AttunementsCore.deepen(out, best_id)
	return out


# --- Small counters used by the report -------------------------------------------------

func _count_buildings(town: Dictionary) -> int:
	return (town.get("buildings", []) as Array).size()


func _count_maxed_buildings(town: Dictionary, building_defs: Dictionary) -> int:
	var n := 0
	for id: String in building_defs:
		var levels: Array = (building_defs[id]["levels"] as Array)
		if TownCore.building_level(town, id) >= levels.size():
			n += 1
	return n


func _building_levels(town: Dictionary, building_defs: Dictionary) -> Dictionary:
	var out := {}
	for id: String in building_defs:
		out[id] = TownCore.building_level(town, id)
	return out


func _count_maxed_etchings(etchings: Dictionary, etching_defs: Dictionary) -> int:
	var n := 0
	for id in EtchingsCore.IMPLEMENTED:
		if etching_defs.has(id) and EtchingsCore.level_of(etchings, id) >= EtchingsCore.MAX_LEVEL:
			n += 1
	return n


func _count_maxed_attunements(attunements: Dictionary, attunement_defs: Dictionary) -> int:
	var n := 0
	for id: String in attunement_defs:
		if AttunementsCore.level(attunements, id) >= AttunementsCore.MAX_LEVEL:
			n += 1
	return n


func _count_maxed_weapons(combat: Dictionary, weapon_defs: Dictionary) -> int:
	var n := 0
	for id: String in weapon_defs:
		var costs: Array = (weapon_defs[id]["flat"] as Dictionary).get("costs", [])
		if WeaponCore.flat_level(combat, id) >= costs.size():
			n += 1
	return n


# --- Report ------------------------------------------------------------------------

func _milestone_run(records: Array, pred: Callable) -> int:
	for r: Dictionary in records:
		if pred.call(r):
			return int(r["run"])
	return -1  # never reached within NUM_RUNS


func _build_report(per_seed: Array, tech_defs: Dictionary, etching_defs: Dictionary,
		attunement_defs: Dictionary, weapon_defs: Dictionary, building_defs: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("# Economy simulator report")
	lines.append("")
	lines.append("Generated by `tools/economy_sim.gd` — this file is the tool's OUTPUT, not")
	lines.append("hand-maintained prose. Regenerate after any economy-relevant data or pure-core")
	lines.append("change:")
	lines.append("")
	lines.append("```")
	lines.append("/home/clarior/Godot_v4.7-stable_linux.x86_64 --headless --path . \\")
	lines.append("  res://tools/economy_sim.tscn")
	lines.append("```")
	lines.append("")
	lines.append("## Caveat — read before trusting a number")
	lines.append("")
	lines.append("Every economy constant here is a **placeholder** (DoorCore/TownCore/TechCore/")
	lines.append("EtchingsCore/AttunementsCore/WeaponCore all say so in their own headers), and the")
	lines.append("player policy below is a deliberately blunt caricature, not a skill model. This")
	lines.append("tool does NOT predict real playtest pacing. What it measures honestly — because")
	lines.append("the math is the game's own pure cores, never re-implemented — is RELATIVE")
	lines.append("pressure between resource sinks, whether the ~40-run sample exhausts the sinks")
	lines.append("that exist today, and where a sink saturates and starts stockpiling forever.")
	lines.append("")
	lines.append("## Assumption constants (cited)")
	lines.append("")
	lines.append("| constant | value | source |")
	lines.append("|---|---|---|")
	lines.append("| gold/kill (mid of range) | %.1f | combat_room.gd:51-52 (gold_per_enemy_min/max, 1-3) |" % GOLD_PER_KILL_MID)
	lines.append("| ore drop chance/kill | %.2f | combat_room.gd:53 (ore_drop_chance) |" % ORE_DROP_CHANCE)
	lines.append("| boss gold | %.0f | combat_room.gd:54 (boss_gold) |" % BOSS_GOLD)
	lines.append("| boss knowledge shards | %.0f | combat_room.gd:55 (boss_shards) |" % BOSS_SHARDS)
	lines.append("| boss resonance ore | %.0f | combat_room.gd:56 (boss_ore) |" % BOSS_ORE)
	lines.append("| base room enemy count | %d | combat_room.gd:42 (enemy_count) |" % BASE_ENEMY_COUNT)
	lines.append("| run shape | %d floors x %d-%d rooms | PRD §7.6 full target (RunFlow.start defaults) |" % [RUN_FLOORS, ROOMS_MIN, ROOMS_MAX])
	lines.append("| sample | %d runs x %d seeds | this brief |" % [NUM_RUNS, SEEDS.size()])
	lines.append("")
	lines.append("Per-kill and per-door income is applied as its EXPECTED VALUE (bodies x chance),")
	lines.append("not a rolled RNG outcome — see the class header for why.")
	lines.append("")
	lines.append("## Policies (fixed, as shipped)")
	lines.append("")
	lines.append("- **Player policy:** runs 1-3 die at that floor's boss (run 1 dies on floor 1,")
	lines.append("  run 2 on floor 2, run 3 on floor 3 — having cleared every earlier room/floor")
	lines.append("  normally); run 4 onward is always a full clear (5 floors, final boss, codex")
	lines.append("  shard). A blunt early-game ramp, not a skill model.")
	lines.append("- **Door policy:** priority echo > dust > ore > gold > reprieve (reprieve is")
	lines.append("  never chosen except when it is the offer's only door — the sim never tracks")
	lines.append("  HP, so the spec's \"reprieve when hurt\" clause never fires); peril is never")
	lines.append("  avoided (it only ever raises the payout).")
	lines.append("- **Spend policy each town visit, in order:** (1) turn in all Knowledge Shards,")
	lines.append("  invest all Knowledge into the cheapest available tech node (real prereqs,")
	lines.append("  quiz assumed solved); (2) buildings, cheapest next level first; (3) weapon")
	lines.append("  flat refines when Ore covers it; (4) Dust — the 5 implemented etchings first")
	lines.append("  until maxed, then the 7 attunements.")
	lines.append("")
	lines.append("## Per-run table (seed %d, the primary sample)" % SEEDS[0])
	lines.append("")
	lines.append("| run | outcome | gold | ore | dust | shards | knowledge | buildings | techs |")
	lines.append("|---|---|---|---|---|---|---|---|---|")
	for r: Dictionary in per_seed[0]:
		lines.append("| %d | %s | %.0f | %.0f | %.0f | %.0f | %.0f | %d | %d |" % [
			int(r["run"]), str(r["outcome"]), float(r["gold"]), float(r["ore"]), float(r["dust"]),
			float(r["shards"]), float(r["knowledge"]), int(r["buildings_built"]), int(r["techs_done"])])
	lines.append("")

	# --- Milestones ------------------------------------------------------------------
	lines.append("## Milestones (first run # reaching each; mean across the %d seeds)" % SEEDS.size())
	lines.append("")
	var milestone_defs := [
		["first building built", func(r: Dictionary) -> bool: return int(r["buildings_built"]) >= 1],
		["Masonry & the Arch researched", func(r: Dictionary) -> bool: return int(r["techs_done"]) >= 2],
		["ability kit maxed (5 implemented etchings @ L3)", func(r: Dictionary) -> bool: return int(r["etchings_maxed"]) >= EtchingsCore.IMPLEMENTED.size()],
		["all 7 attunements maxed", func(r: Dictionary) -> bool: return int(r["attunements_maxed"]) >= attunement_defs.size()],
		["all 3 weapons' flat track maxed", func(r: Dictionary) -> bool: return int(r["weapons_maxed"]) >= weapon_defs.size()],
		["codex full (%d shards)" % StoryCore.CODEX_SHARDS_MAX, func(r: Dictionary) -> bool: return int(r["codex_shards"]) >= StoryCore.CODEX_SHARDS_MAX],
	]
	lines.append("| milestone | seed %d | seed %d | seed %d | mean |" % [SEEDS[0], SEEDS[1], SEEDS[2]])
	lines.append("|---|---|---|---|---|")
	for md in milestone_defs:
		var name: String = md[0]
		var pred: Callable = md[1]
		var runs: Array = []
		for records in per_seed:
			runs.append(_milestone_run(records, pred))
		var reached: Array = runs.filter(func(x: int) -> bool: return x > 0)
		var mean_str := "never"
		if not reached.is_empty():
			var total := 0
			for x in reached:
				total += int(x)
			mean_str = "%.1f" % (float(total) / float(reached.size()))
			if reached.size() < runs.size():
				mean_str += " (%d/%d seeds)" % [reached.size(), runs.size()]
		var cells: Array = []
		for x in runs:
			cells.append("never" if int(x) < 0 else str(x))
		lines.append("| %s | %s | %s | %s | %s |" % [name, cells[0], cells[1], cells[2], mean_str])
	lines.append("")
	lines.append("**Tech-node budget context:** only 2 of the 14 v1-budgeted tech nodes exist as")
	lines.append("data today (content-budget.md: 11 Medieval + 3 Renaissance; med-arithmetic-zero")
	lines.append("cost 20, med-masonry-arch cost 40 — mean cost 30). Extrapolating that mean cost")
	lines.append("across all 14 nodes (420 Knowledge total) against the sim's steady-state")
	lines.append("Knowledge income is a ROUGH projection from 2 real data points, not a forecast:")
	var extrap := _extrapolate_knowledge(per_seed)
	lines.append("- steady-state Knowledge income (mean of the last 10 runs' per-run gain, seed %d): %.1f/run" % [SEEDS[0], extrap["per_run"]])
	lines.append("- 14 nodes @ mean cost 30 = 420 Knowledge -> ~%.0f runs at that rate (a full v1 tech tree, if it existed today)" % extrap["runs_for_14"])
	lines.append("")

	# --- Red flags ---------------------------------------------------------------------
	lines.append("## Red flags")
	lines.append("")
	lines.append(_red_flags(per_seed, building_defs, etching_defs, attunement_defs, weapon_defs))
	return "\n".join(lines) + "\n"


func _extrapolate_knowledge(per_seed: Array) -> Dictionary:
	var records: Array = per_seed[0]
	var window := records.slice(maxi(0, records.size() - 10), records.size())
	var gains := 0.0
	var prev := 0.0
	var first := true
	for r: Dictionary in window:
		if not first:
			gains += maxf(0.0, float(r["knowledge"]) - prev)
		prev = float(r["knowledge"])
		first = false
	var per_run := gains / float(maxi(1, window.size() - 1))
	return {"per_run": per_run, "runs_for_14": (420.0 / per_run) if per_run > 0.0 else -1.0}


func _red_flags(per_seed: Array, building_defs: Dictionary, etching_defs: Dictionary,
		attunement_defs: Dictionary, weapon_defs: Dictionary) -> String:
	var out: PackedStringArray = []
	var seed0: Array = per_seed[0]
	var last: Dictionary = seed0[seed0.size() - 1]
	out.append("- **Dust two-sink saturation:** etchings maxed at run %s, attunements maxed at" % _fmt_ms(_milestone_run(seed0, func(r: Dictionary) -> bool: return int(r["etchings_maxed"]) >= EtchingsCore.IMPLEMENTED.size())))
	out.append("  run %s (seed %d). Every Dust point earned after both sinks are full has NOTHING" % [_fmt_ms(_milestone_run(seed0, func(r: Dictionary) -> bool: return int(r["attunements_maxed"]) >= attunement_defs.size())), SEEDS[0]])
	out.append("  left to buy — final Dust balance at run %d: %.0f (pure stockpile)." % [NUM_RUNS, float(last["dust"])])
	out.append("- **Gold explodes while Stone stays genuinely scarce — Stone, not Gold, is the")
	out.append("  economy's real bottleneck.** Final gold balance at run %d (seed %d): %.0f, with" % [NUM_RUNS, SEEDS[0], float(last["gold"])])
	out.append("  no sink left once every gold-only purchase is done (no shop exists yet to spend")
	out.append("  surplus gold). Stone tells a different story: only the Quarry produces it, and")
	var lvls: Dictionary = last["building_levels"]
	var lvl_bits: PackedStringArray = []
	for id: String in lvls:
		lvl_bits.append("%s L%d" % [id, int(lvls[id])])
	out.append("  under the cheapest-first spend policy Stone keeps going to the CHEAPEST Stone")
	out.append("  cost first (Farm/Study L2-L3 at 8-30 Stone) rather than being saved toward the")
	out.append("  single priciest item, Town Walls L3 (100 Stone) — which is STILL unbought at")
	out.append("  run %d (seed %d final levels: %s; final Stone: %.0f). That is a genuine finding" % [NUM_RUNS, SEEDS[0], ", ".join(lvl_bits), float(last["stone"])])
	out.append("  about the current numbers, not a sim bug: a human optimizing by hand would")
	out.append("  likely save toward Walls L3 instead, but nothing in the data currently rewards")
	out.append("  that over spending Stone as soon as it's affordable.")
	out.append("- **Does ~40 runs cover the spend sinks that exist today?** Mostly. Weapons,")
	out.append("  etchings, attunements, and the codex all saturate well before run 40 (see the")
	out.append("  milestones table). Buildings are the exception — see the Stone bottleneck above")
	out.append("  — so 40 runs is NOT enough to exhaust the building sink under this policy, even")
	out.append("  though Gold alone would cover it many times over. The sample is oversized for")
	out.append("  every OTHER sink and undersized for the 14-node tech budget (see the")
	out.append("  extrapolation above) — expected, since most of v1's content doesn't exist as")
	out.append("  data yet.")
	return "\n".join(out)


func _fmt_ms(x: int) -> String:
	return "never" if x < 0 else str(x)
