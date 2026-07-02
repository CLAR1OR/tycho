extends RefCounted
class_name WeaponCore
## Weapons as data (PRD §7.2). A weapon definition is a set of add/mult MODS over
## the player's exported base kit (same mod shape as Echoes) plus a kind
## (melee/ranged) and a FLAT upgrade track bought at Mara's Forge with Resonance
## Ore. The Sword is the baseline — empty mods — so the human's feel-tuned player
## exports stay the single source of combat feel; other weapons are RELATIVE to it.
##
## Persistent state lives in the save's combat section:
##   combat.current_weapon: String
##   combat.weapons: {id: {flat: int, resonance: []}}   (resonance effects = later)
## Pure helpers here; the forge UI and combat_room do the wiring.
## Apply order on a fresh room player: weapon first (baseline kit), echoes on top.

static var _defs_cache: Dictionary = {}


static func defs() -> Dictionary:
	if _defs_cache.is_empty():
		_defs_cache = DataLoader.load_domain("weapons")
	return _defs_cache


static func flat_level(combat: Dictionary, weapon_id: String) -> int:
	return int((combat.get("weapons", {}).get(weapon_id, {}) as Dictionary).get("flat", 0))


## Pure update: a NEW combat dict with the weapon's flat level set.
static func with_flat_level(combat: Dictionary, weapon_id: String, level: int) -> Dictionary:
	var out := combat.duplicate(true)
	if not out.has("weapons"):
		out["weapons"] = {}
	if not out["weapons"].has(weapon_id):
		out["weapons"][weapon_id] = {"flat": 0, "resonance": []}
	out["weapons"][weapon_id]["flat"] = level
	return out


## Resonance-Ore cost of the NEXT flat level ({} = maxed).
static func next_flat_cost(def: Dictionary, current_level: int) -> Dictionary:
	var costs: Array = (def.get("flat", {}) as Dictionary).get("costs", [])
	if current_level >= costs.size():
		return {}
	return {"resonance-ore": float(costs[current_level])}


## Damage multiplier the flat track grants at `level`.
static func damage_mult(def: Dictionary, level: int) -> float:
	return 1.0 + float((def.get("flat", {}) as Dictionary).get("damage_mult_per_level", 0.0)) * float(level)


## Configure a (fresh) player for this weapon: kind, relative mods, flat-track
## damage, and projectile stats for ranged kinds.
static func apply_to_player(player: Player, def: Dictionary, level: int) -> void:
	player.weapon_kind = str(def.get("kind", "melee"))
	EchoCore.apply_to_player(player, {"id": str(def.get("id", "?")), "mods": def.get("mods", [])})
	var mult := damage_mult(def, level)
	if mult != 1.0:
		player.attack_damage = roundi(player.attack_damage * mult)
		player.attack_damage_finisher = roundi(player.attack_damage_finisher * mult)
	var projectile: Variant = def.get("projectile")
	if projectile is Dictionary:
		player.arrow_speed = float((projectile as Dictionary).get("speed", player.arrow_speed))
