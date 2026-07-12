extends RefCounted
class_name StrataCore
## Pure, deterministic strata logic for the dungeon floors (design/dungeon-strata.md,
## architecture-schemas.md §9). Given a floor's stratum profile it answers three
## questions, all seeded and headless-testable (godot-conventions rule 3): which
## HAZARDS a combat room gets, WHERE to scatter hazards/props on the shared 56x56 kit,
## and what ENVIRONMENT to paint (a defaults-merge so an old/partial floor file keeps
## today's look). The live wiring — applying the env, spawning Hazard/prop nodes —
## lives in combat_room.gd; this owns only the maths.
##
## Determinism mirrors WaveCore/DoorCore: everything is a function of (profile, room,
## seed) with an internal RNG salted per concern, so a checkpoint resume (which
## regenerates by seed, no schema change) and the headless smoke both reproduce it.
##
## Every NUMBER a floor/hazard file carries is a HUMAN placeholder — densities, env
## colours, keep-outs. They are data / dial-board values, not code structure.

# --- Environment defaults ---------------------------------------------------------
# The shared kit's CURRENT look (combat_room.tscn's Environment / DirectionalLight /
# Ground-Wall-Obstacle materials). A floor file's `environment` dict overrides any
# subset of these keys; anything it omits keeps the default — so a floor with no
# `environment` at all renders exactly as today (the deniability floor, floor 1, sits
# closest to this). Colour keys hold Color, the rest hold float/bool — except `ramp`,
# an OPTIONAL array of "#rrggbb" stops (dark->light) for the style layer's toon ramp
# (StyleCore.ramp_stops uses it verbatim; empty/absent = derive from the colours above).
const ENV_DEFAULTS: Dictionary = {
	"background_color": Color(0.1, 0.09, 0.14),
	"ambient_color": Color(0.45, 0.45, 0.55),
	"ambient_energy": 0.6,
	"light_color": Color(1.0, 1.0, 1.0),
	"light_energy": 1.0,
	"ground_color": Color(0.2, 0.19, 0.26),
	"wall_color": Color(0.3, 0.28, 0.36),
	"obstacle_color": Color(0.34, 0.29, 0.24),
	"fog_enabled": false,
	"fog_color": Color(0.1, 0.12, 0.18),
	"fog_density": 0.0,
	"ramp": [],
}

# --- Placement bounds (placeholders; the room is 56x56, walls at +-27) -------------
# Hazards live in the central play field, well inside the walls and clear of BOTH the
# south player spawn and the north exit/door line (z ~ -23, which sits outside this
# half-extent already) — the dead-roll rule (a hazard never blocks the only path) plus
# smoke safety (the idle test player at the spawn is never sat on).
const HALF_EXTENT := 20.0          # hazards/props scatter within +-this on x/z
const KEEP_OUT_SPAWN := 8.0        # clear radius around the player spawn point
const MIN_SPACING := 4.0           # min gap between two placed hazards
const PROP_HALF_EXTENT := 24.0     # props (dressing, no collision) may sit nearer walls
const PROP_MIN_SPACING := 3.0
const _PLACE_TRIES := 24           # candidate attempts per point before relaxing spacing


## The environment a floor renders with: ENV_DEFAULTS with the profile's `environment`
## merged over it. Colour values may be authored as "#rrggbb" strings (parsed here) or
## left out; numbers are floats; bools are bools. Unknown keys in the file are ignored
## (never crash). Pure — Color/Color.html are value types, not engine singletons.
static func environment_of(profile: Dictionary) -> Dictionary:
	var env := ENV_DEFAULTS.duplicate()
	var raw: Dictionary = profile.get("environment", {})
	for key: Variant in raw:
		if not ENV_DEFAULTS.has(key):
			continue  # a stray/future field — skip, don't crash
		var d: Variant = ENV_DEFAULTS[key]
		var v: Variant = raw[key]
		if d is Color:
			env[key] = _to_color(v, d)
		elif d is Array:
			env[key] = _to_ramp(v)
		elif d is bool:
			env[key] = bool(v)
		else:
			env[key] = float(v)
	return env


## A single environment value with a caller default (thin read helper over the merge).
static func env_value(profile: Dictionary, key: String, default: Variant) -> Variant:
	return environment_of(profile).get(key, default)


## Which hazard ids a room gets. ONLY combat rooms get hazards (`is_combat`); reprieve
## rooms are breathers and boss arenas stay clean this slice — both return []. Count is
## the density interpolated across the floor's rooms (early_rooms -> late_rooms), with
## the fractional part as a seeded probability. When count >= 1 the FIRST id is always
## the floor's signature hazard; extras are drawn seeded from [signature] + pool.
## Deterministic in (profile, room_index, seed).
static func hazard_plan(profile: Dictionary, room_index: int, rooms_this_floor: int,
		is_combat: bool, seed: int) -> Array[String]:
	var out: Array[String] = []
	if not is_combat:
		return out
	var haz: Dictionary = profile.get("hazards", {})
	if haz.is_empty():
		return out
	var signature := str(haz.get("signature", ""))
	if signature == "":
		return out
	var floor_id := int(profile.get("id", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "hazards", floor_id, room_index])
	var expected := _density_at(haz.get("density", {}), room_index, rooms_this_floor)
	var count := int(floor(expected))
	if rng.randf() < (expected - float(count)):
		count += 1
	if count <= 0:
		return out
	out.append(signature)  # signature-first rule
	var pool: Array = [signature]
	for p: Variant in haz.get("pool", []):
		pool.append(str(p))
	for _i in range(1, count):
		out.append(str(pool[rng.randi() % pool.size()]))
	return out


## The interpolated expected hazard count at a room (linear early_rooms -> late_rooms
## across room indices 1..rooms_this_floor). Exposed for tuning/tests.
static func _density_at(density: Dictionary, room_index: int, rooms_this_floor: int) -> float:
	var early := float(density.get("early_rooms", 0.0))
	var late := float(density.get("late_rooms", 0.0))
	var t := 0.0
	if rooms_this_floor > 1:
		t = clampf(float(room_index - 1) / float(rooms_this_floor - 1), 0.0, 1.0)
	return lerpf(early, late, t)


## Deterministic scatter of `count` hazard points on the play field, each outside the
## spawn keep-out and (best effort) MIN_SPACING apart. ALWAYS returns exactly `count`
## points (keep-outs are strictly honoured; spacing relaxes only if the field is too
## packed) so the room spawns as many hazards as the plan named. y = 0 (floor level).
## `extra_keep_outs` (optional, [{center: Vector2, radius: float}]) are additional HARD
## keep-out circles — the room-layout obstacle footprints (LayoutCore), 2026-07-12.
static func placement_points(count: int, seed: int, half_extent: float = HALF_EXTENT,
		keep_out_center := Vector2(0.0, 18.0), keep_out_radius: float = KEEP_OUT_SPAWN,
		min_spacing: float = MIN_SPACING, extra_keep_outs: Array = []) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "placement"])
	var pts: Array[Vector3] = []
	for _i in count:
		var chosen := _pick_point(rng, half_extent, keep_out_center, keep_out_radius,
			min_spacing, pts, extra_keep_outs)
		pts.append(chosen)
	return pts


## A prop plan: an id + position per prop, scattered like hazards but nearer the walls
## (props are dressing with NO collision — the dead-roll rule needs nothing of them).
## Returns [{id, pos}]. Deterministic in (prop_ids, seed). `extra_keep_outs` as above.
static func prop_plan(prop_ids: Array, seed: int, half_extent: float = PROP_HALF_EXTENT,
		keep_out_center := Vector2(0.0, 18.0), keep_out_radius: float = KEEP_OUT_SPAWN,
		min_spacing: float = PROP_MIN_SPACING, extra_keep_outs: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "props"])
	var out: Array = []
	var placed: Array[Vector3] = []
	for id: Variant in prop_ids:
		var p := _pick_point(rng, half_extent, keep_out_center, keep_out_radius,
			min_spacing, placed, extra_keep_outs)
		placed.append(p)
		out.append({"id": str(id), "pos": p})
	return out


# --- Helpers ----------------------------------------------------------------------

static func _pick_point(rng: RandomNumberGenerator, half_extent: float,
		keep_out_center: Vector2, keep_out_radius: float, min_spacing: float,
		placed: Array[Vector3], extra_keep_outs: Array = []) -> Vector3:
	var fallback := Vector3.ZERO
	for attempt in _PLACE_TRIES:
		var x := rng.randf_range(-half_extent, half_extent)
		var z := rng.randf_range(-half_extent, half_extent)
		if Vector2(x, z).distance_to(keep_out_center) < keep_out_radius:
			continue  # keep-outs are HARD — never relaxed
		if _in_extra_keep_out(Vector2(x, z), extra_keep_outs):
			continue  # obstacle footprints are HARD too — no hazard inside a pillar
		var p := Vector3(x, 0.0, z)
		fallback = p  # last keep-out-safe candidate, used if spacing can't be met
		if _spaced(p, placed, min_spacing):
			return p
	return fallback  # keep-out-safe but tight — accept so count is always met


static func _in_extra_keep_out(p: Vector2, keep_outs: Array) -> bool:
	for ko: Dictionary in keep_outs:
		if p.distance_to(ko["center"]) < float(ko["radius"]):
			return true
	return false


static func _spaced(p: Vector3, placed: Array[Vector3], min_spacing: float) -> bool:
	for q in placed:
		if p.distance_to(q) < min_spacing:
			return false
	return true


static func _to_color(v: Variant, fallback: Color) -> Color:
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	if v is Color:
		return v
	return fallback


## Parse the optional `ramp` env value (["#rrggbb", ...] -> Array[Color]). Invalid
## entries are skipped, a non-array yields [] — never crash; [] means "no explicit
## ramp, derive one" (StyleCore).
static func _to_ramp(v: Variant) -> Array[Color]:
	var out: Array[Color] = []
	if v is Array:
		for item: Variant in v:
			if item is Color:
				out.append(item)
			elif item is String and Color.html_is_valid(item):
				out.append(Color.html(item))
	return out
