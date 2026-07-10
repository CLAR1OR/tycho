extends RefCounted
class_name DoorCore
## Door choice + the in-run healing/cache math (design/run-structure.md). This is the
## PURE part, unit-testable headless: given (run seed, floor, rooms_this_floor, floor
## profile) it lays out a whole floor's DOOR PLAN deterministically, and it owns the
## cache-reward, peril-modifier and %-of-missing heal formulas. The live wiring
## (portals, wellsprings, Ledger writes) lives in combat_room.gd + game.gd; RunState
## only HOLDS the plan and the chosen door.
##
## A door plan is {floor, offers}: `offers` is a list of per-transition offers, one
## per room the player CLEARS on this floor. offers[r-1] is shown on clearing room r
## and previews what room r+1 pays. Each offer is 1-2 doors {sigil, peril}; the LAST
## offer is always a single boss door (never peril). The plan being a plain list is
## also the Cartography FORESIGHT hook (one-room-ahead lookahead = read offers[r]) —
## that tech node isn't built, so foresight is NOT wired here, only made trivial.
##
## Determinism matters twice: a checkpoint resumes at floor start and regenerates the
## identical plan from the seed (no checkpoint schema change), and a reproducible plan
## is what lets the whole thing be tested.

const SIGIL_GOLD := "gold"
const SIGIL_ORE := "ore"
const SIGIL_DUST := "dust"
const SIGIL_ECHO := "echo"
const SIGIL_REPRIEVE := "reprieve"
const SIGIL_BOSS := "boss"

## The sigils that pay a resource cache (the rest pay an echo / a heal / the boss).
const CACHE_SIGILS: Array[String] = [SIGIL_GOLD, SIGIL_ORE, SIGIL_DUST]

## Cache sigil -> the Ledger resource it pays into.
const SIGIL_RESOURCE: Dictionary = {
	SIGIL_GOLD: "gold",
	SIGIL_ORE: "resonance-ore",
	SIGIL_DUST: "resonance-dust",
}

# --- Economy placeholders (NOT feel numbers — run-economy tuning is an open question,
# PRD §13; dial these like the drop rates in combat_room). A cache = base + per-floor.
# Rebalanced 2026-07-10 against tools/economy_sim.gd (caches cut ~50%; dust cut least —
# early etching unlocks must stay reachable within a few runs). ---
const CACHE_BASE: Dictionary = {"gold": 6.0, "ore": 0.5, "dust": 1.5}
const CACHE_PER_FLOOR: Dictionary = {"gold": 3.0, "ore": 0.25, "dust": 0.5}
const PERIL_REWARD_MULT := 2.0  # a peril room pays double

# --- Elite-modifier stub (PRD §7.7 — peril rooms are its first concrete use). Runtime
# spawn multipliers over the enemy's feel-tuned exports (same relative-mod philosophy
# as WeaponCore/echoes on the player) — placeholders, never edit the enemy .tscn. ---
const PERIL_HEALTH_MULT := 1.5
const PERIL_DAMAGE_MULT := 1.25

# --- Healing valves (design/run-structure.md Part 2) — all % of MISSING hp, never of
# max (anti-snowball vs Vitality); no full heals anywhere mid-run. Placeholders. ---
const WELLSPRING_HEAL_PCT := 0.40  # the Reprieve-door breather
const BOSS_HEAL_PCT := 0.30        # automatic on every floor-boss kill

# --- Offer shaping ---
const SINGLE_DOOR_CHANCE := 0.35   # weighted chance an offer shows just one door (no fake choices)
const PITY_ECHO := 2               # >= 2 echo doors per floor (PRD §10 RNG-protection)
const PITY_REPRIEVE := 1           # >= 1 reprieve door per floor


## Lay out a whole floor's door plan. `weights` is the profile's door_weights
## {sigil: weight}; `peril_chance` its per-door peril probability. Deterministic in
## (rng_seed, floor_num, rooms_this_floor, weights, peril_chance).
static func generate_plan(rng_seed: int, floor_num: int, rooms_this_floor: int,
		weights: Dictionary, peril_chance: float) -> Dictionary:
	var offers: Array = []
	var total_offers := maxi(0, rooms_this_floor - 1)
	if total_offers == 0:
		return {"floor": floor_num, "offers": offers}  # degenerate (boss-only floor)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rng_seed, "doors", floor_num])
	var non_boss := total_offers - 1  # the last offer is the boss door, appended below
	var sigils: Array = weights.keys()
	sigils.sort()  # dict order is insertion order — sort so the weighted draw is stable
	var pc := clampf(peril_chance, 0.0, 1.0)
	# Draw doors left-to-right; _draw_sigil keeps each offer's sigils distinct AND never
	# lets a DRAWN door make a sigil appear in three consecutive offers.
	var capacity := 0
	for i in non_boss:
		var doors := 1 if rng.randf() < SINGLE_DOOR_CHANCE else 2
		var offer: Array = []
		var used: Array[String] = []
		for _slot in doors:
			var sigil := _draw_sigil(sigils, weights, used, offers, i, rng)
			if sigil == "":
				continue  # nothing legal (over-constrained) — drop this door
			used.append(sigil)
			offer.append({"sigil": sigil, "peril": rng.randf() < pc})
		offers.append(offer)
		capacity += offer.size()
	# Pity: guarantee echoes first, then a reprieve, degrading gracefully when the floor
	# is too small to fit them (guarantee min(target, capacity)). Conversions only ever
	# overwrite CACHE doors and stay triple-safe, so the two passes never fight.
	var target_echo := mini(PITY_ECHO, capacity)
	_ensure_pity(offers, non_boss, SIGIL_ECHO, target_echo)
	var target_reprieve := mini(PITY_REPRIEVE, maxi(0, capacity - target_echo))
	_ensure_pity(offers, non_boss, SIGIL_REPRIEVE, target_reprieve)
	offers.append([{"sigil": SIGIL_BOSS, "peril": false}])
	return {"floor": floor_num, "offers": offers}


## The offer shown on clearing room `room_index` (1-based within the floor). [] when
## there is none (room 1's clear DOES have offers[0]; the boss room has none).
static func offer_for_room(plan: Dictionary, room_index: int) -> Array:
	var offers: Array = plan.get("offers", [])
	var idx := room_index - 1
	if idx < 0 or idx >= offers.size():
		return []
	return offers[idx]


## The cache a sigil pays on clearing the room entered through it, scaled by floor and
## doubled under peril. {} for the non-cache sigils (echo / reprieve / boss / empty).
static func cache_reward(sigil: String, floor_num: int, peril: bool) -> Dictionary:
	if not CACHE_SIGILS.has(sigil):
		return {}
	var amount := float(CACHE_BASE[sigil]) + float(CACHE_PER_FLOOR[sigil]) * float(maxi(0, floor_num - 1))
	if peril:
		amount *= PERIL_REWARD_MULT
	return {"resource": str(SIGIL_RESOURCE[sigil]), "amount": amount}


## A peril room's runtime enemy stats (applied at spawn over the exports, never saved).
static func peril_hp(base: int) -> int:
	return maxi(1, roundi(float(base) * PERIL_HEALTH_MULT))


static func peril_damage(base: int) -> int:
	return maxi(1, roundi(float(base) * PERIL_DAMAGE_MULT))


## HP to restore = pct of the CURRENT missing amount (0 when already full).
static func heal_missing(current_hp: int, max_hp: int, pct: float) -> int:
	return roundi(pct * float(maxi(0, max_hp - current_hp)))


# --- Generation helpers ----------------------------------------------------------

## Weighted draw of one sigil for offer `i`, excluding sigils already in the offer and
## any sigil that already sits in BOTH preceding offers (which would make it the third
## in a row). Returns "" only when every sigil is excluded.
static func _draw_sigil(sigils: Array, weights: Dictionary, used: Array[String],
		offers: Array, i: int, rng: RandomNumberGenerator) -> String:
	var blocked := {}
	for s in used:
		blocked[s] = true
	if i >= 2:
		var prev := _sigils_in(offers[i - 1])
		var prev2 := _sigils_in(offers[i - 2])
		for s in prev:
			if prev2.has(s):
				blocked[s] = true
	var pool: Array[String] = []
	var total := 0.0
	for s: String in sigils:
		if blocked.has(s):
			continue
		pool.append(s)
		total += float(weights[s])
	if pool.is_empty():
		return ""
	var roll := rng.randf() * total
	for s in pool:
		roll -= float(weights[s])
		if roll <= 0.0:
			return s
	return pool[pool.size() - 1]


## Force `sigil` up to `target` occurrences by converting CACHE doors (never other
## specials) in offers that lack it, only where the conversion stays triple-safe.
## Stops early (graceful degradation) when no legal slot remains.
static func _ensure_pity(offers: Array, non_boss: int, sigil: String, target: int) -> void:
	while _count_sigil(offers, non_boss, sigil) < target:
		var placed := false
		for i in non_boss:
			if _sigils_in(offers[i]).has(sigil):
				continue
			for d: Dictionary in offers[i]:
				if not CACHE_SIGILS.has(str(d["sigil"])):
					continue
				if _safe_at(offers, non_boss, i, sigil):
					d["sigil"] = sigil
					placed = true
					break
			if placed:
				break
		if not placed:
			return


## True if putting `sigil` into offer `i` would not create three-in-a-row with any of
## the two offers on either side.
static func _safe_at(offers: Array, non_boss: int, i: int, sigil: String) -> bool:
	var back2 := i - 2 >= 0 and _sigils_in(offers[i - 2]).has(sigil)
	var back1 := i - 1 >= 0 and _sigils_in(offers[i - 1]).has(sigil)
	var fwd1 := i + 1 < non_boss and _sigils_in(offers[i + 1]).has(sigil)
	var fwd2 := i + 2 < non_boss and _sigils_in(offers[i + 2]).has(sigil)
	if back1 and back2:
		return false
	if back1 and fwd1:
		return false
	if fwd1 and fwd2:
		return false
	return true


static func _sigils_in(offer: Array) -> Dictionary:
	var out := {}
	for d: Dictionary in offer:
		out[str(d["sigil"])] = true
	return out


static func _count_sigil(offers: Array, non_boss: int, sigil: String) -> int:
	var n := 0
	for i in non_boss:
		for d: Dictionary in offers[i]:
			if str(d["sigil"]) == sigil:
				n += 1
	return n
