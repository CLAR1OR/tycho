extends RefCounted
class_name EchoCore
## Echoes — the in-run pick-1-of-3 upgrades (PRD §7.5). This class is the pure part:
## the offer generator and the stat-mod math, both unit-testable headless. Echo
## MEANING lives in data/echoes/*.json; the picked list lives on RunState (in-run
## only, never saved — locked design).
##
## v1 slice: `mods` stat effects on the player's exported FEEL numbers (add/mult).
## Weapon-mod / etching-mod / dash-mod echo kinds land with those systems — the
## schema already carries them as plain mods on their stats.
##
## Offer rules:
## - deterministic: same (seed, offer index, picked) → same 3 choices
## - no duplicates within one offer
## - non-stackable echoes leave the pool once picked
## - synergy echoes (`requires`) only enter the pool once ALL prereqs are picked
## - weighted draw (`pool_weight`, default 1.0) — the RNG-protection hook for later

const OFFER_SIZE := 3

static var _defs_cache: Dictionary = {}


## All echo definitions {id: def}, cached after the first load.
static func defs() -> Dictionary:
	if _defs_cache.is_empty():
		_defs_cache = DataLoader.load_domain("echoes")
	return _defs_cache


## Pure weighted draw of up to OFFER_SIZE distinct eligible echo ids.
static func generate_offer(all_defs: Dictionary, picked: Array, rng_seed: int, offer_index: int) -> Array[String]:
	var pool: Array[String] = []
	for id: String in all_defs:
		var def: Dictionary = all_defs[id]
		if not bool(def.get("stackable", false)) and id in picked:
			continue
		var ok := true
		for req: String in def.get("requires", []):
			if req not in picked:
				ok = false
				break
		if ok:
			pool.append(id)
	pool.sort()  # dict order is insertion order — sort so the draw is truly deterministic
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rng_seed, "echo-offer", offer_index])
	var out: Array[String] = []
	while out.size() < OFFER_SIZE and not pool.is_empty():
		var total := 0.0
		for id in pool:
			total += float((all_defs[id] as Dictionary).get("pool_weight", 1.0))
		var roll := rng.randf() * total
		for i in pool.size():
			roll -= float((all_defs[pool[i]] as Dictionary).get("pool_weight", 1.0))
			if roll <= 0.0 or i == pool.size() - 1:
				out.append(pool[i])
				pool.remove_at(i)
				break
	return out


## Pure mod math: apply one echo's `mods` to a {stat: value} dict (numbers only).
## `add` applies before `mult` within a single mod entry. Returns a new dict.
static func apply_mods(values: Dictionary, def: Dictionary) -> Dictionary:
	var out := values.duplicate(true)
	for mod: Dictionary in def.get("mods", []):
		var stat := str(mod.get("stat", ""))
		if not out.has(stat):
			push_error("EchoCore: echo \"%s\" mods unknown stat \"%s\"" % [str(def.get("id", "?")), stat])
			continue
		var v := float(out[stat]) + float(mod.get("add", 0.0))
		v *= float(mod.get("mult", 1.0))
		# Keep ints int (damage, max_health, …) so downstream typing stays honest.
		out[stat] = roundi(v) if out[stat] is int else v
	return out


## Engine-facing shim: read the echo's target stats off the player, run the pure
## math, write them back. Raising max_health also grants the delta as healing
## (picking Vital Core mid-run must not leave you at old-max HP).
static func apply_to_player(player: Player, def: Dictionary) -> void:
	var stats := {}
	for mod: Dictionary in def.get("mods", []):
		var stat := str(mod.get("stat", ""))
		var cur: Variant = player.get(stat)
		if cur == null or not (cur is int or cur is float):
			push_error("EchoCore: player has no numeric stat \"%s\" (echo \"%s\")" % [stat, str(def.get("id", "?"))])
			continue
		stats[stat] = cur
	var max_hp_before: int = player.max_health
	var new_stats := apply_mods(stats, def)
	for stat: String in new_stats:
		player.set(stat, new_stats[stat])
	if player.max_health > max_hp_before:
		player.heal(player.max_health - max_hp_before)
	elif player.health > player.max_health:
		# A max-LOWERING echo (glass-cannon's drawback) must not leave current HP above
		# the new cap — clamp immediately (restore_health clamps + emits health_changed).
		player.restore_health(player.max_health)


## Re-apply the whole picked list to a fresh player instance (rooms spawn a new
## Player each — RunState carries the list, this makes it stick).
static func apply_all_to_player(player: Player, picked: Array) -> void:
	var all_defs := defs()
	for id: String in picked:
		if all_defs.has(id):
			apply_to_player(player, all_defs[id])
		else:
			push_error("EchoCore: picked unknown echo \"%s\"" % id)
