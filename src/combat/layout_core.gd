extends RefCounted
class_name LayoutCore
## Pure, deterministic room-layout logic (PRD §7.6: ~30 shared combat layouts +
## 5 boss arenas + 3 reprieve layouts; design/dungeon-strata.md § Room layouts).
## A layout (data/layouts/*.json) arranges a tiny kit vocabulary — pillar / block —
## inside the one shared 56x56 room (IC-5: one geometry kit, no per-floor tilesets).
## This owns the maths only: seeded picking, geometry validation (incl. a flood-fill
## path guarantee), and obstacle-footprint queries for placement keep-outs. Building
## the actual StaticBody3D obstacles lives in combat_room.gd.
##
## Determinism mirrors StrataCore/WaveCore: everything is a function of
## (defs, kind, floor, room_index, seed) — a checkpoint resume (regenerates by seed)
## and the headless smoke both reproduce every pick.
##
## A layout that fails validate() is a CONTENT BUG: the game-side loader warns and
## falls back to the .tscn's authored obstacles — it never crashes a run.

const KIND_COMBAT := "combat"
const KIND_REPRIEVE := "reprieve"
const KIND_BOSS := "boss"
const KINDS: Array[String] = [KIND_COMBAT, KIND_REPRIEVE, KIND_BOSS]

const OB_PILLAR := "pillar"
const OB_BLOCK := "block"
const DEFAULT_PILLAR_RADIUS := 1.2

# --- Room invariants (fixed points of combat_room.tscn — NOT dials) ----------------
# Interior walls sit at +-27; footprints must stay fully inside +-26 so nothing clips.
const INTERIOR_HALF := 26.0
# Exit/door line at z = -23 (doors at x in {-6, 0, 6}): the full-width strip
# z <= -20 stays obstacle-free in ALL layouts, so doors are always walkable.
const DOOR_STRIP_Z := -20.0
# Player spawn (combat_room.PLAYER_SPAWN) — a clear circle so nobody spawns walled-in.
const SPAWN_POINT := Vector2(0.0, 18.0)
const SPAWN_CLEAR_RADIUS := 6.0
# Reprieve rooms: the Wellspring at (0, -2) keeps a clear approach.
const WELLSPRING_POINT := Vector2(0.0, -2.0)
const WELLSPRING_CLEAR_RADIUS := 4.0
# Boss arenas: the central band stays completely clear (boss spawn (0,-14), escorts
# (+-8,-10), final-floor artifact (0,-18), den-warden burrow room) — obstacles are
# perimeter drama only.
const BOSS_BAND_HALF_X := 13.0
const BOSS_BAND_Z_MIN := -21.0
const BOSS_BAND_Z_MAX := 3.0

# --- Flood-fill connectivity ---------------------------------------------------------
const GRID_MARGIN := 0.8            # player half-width padding when rasterizing footprints
const GRID_MIN := -26               # 1 m grid of cell centres over the interior
const GRID_MAX := 26
const REACHABLE_MIN_FRACTION := 0.6 # spawn must reach >= this fraction of open cells
const MAX_POCKET_CELLS := 8         # any single sealed open pocket bigger than this errors
const DOOR_CELL := Vector2i(0, -22) # the BFS target on the door line
const EPS := 0.001


## Deterministic layout pick. Filters `defs` (a DataLoader "layouts" domain dict) by
## kind — boss additionally by `floor` — and returns one def ({} when the filtered
## pool is empty; the caller keeps the authored .tscn obstacles).
## COMBAT: within one floor, layouts must not repeat until the pool is exhausted —
## the pool is seeded-shuffled once per floor (hash([seed, "layout", floor])) and
## indexed positionally by room. BOSS/REPRIEVE: a plain seeded pick.
static func pick(defs: Dictionary, kind: String, floor_num: int, room_index: int,
		seed: int) -> Dictionary:
	var pool: Array = []
	var ids: Array = defs.keys()
	ids.sort()  # DirAccess file order is not contractual — sort for determinism
	for id: Variant in ids:
		var def: Dictionary = defs[id]
		if str(def.get("kind", "")) != kind:
			continue
		if kind == KIND_BOSS and int(def.get("floor", 0)) != floor_num:
			continue
		pool.append(def)
	if pool.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	if kind == KIND_COMBAT:
		rng.seed = hash([seed, "layout", floor_num])
		for i in range(pool.size() - 1, 0, -1):  # Fisher–Yates, seeded
			var j := rng.randi_range(0, i)
			var tmp: Variant = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		return pool[maxi(room_index - 1, 0) % pool.size()]
	rng.seed = hash([seed, "layout", kind, floor_num, room_index])
	return pool[rng.randi() % pool.size()]


## Validate one layout def. Returns error strings ([] = ok): known kind, well-formed
## obstacles, footprints in bounds, the per-kind clear zones honoured, and the
## flood-fill path guarantee (spawn reaches the door line + no sealed pockets).
static func validate(def: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var kind := str(def.get("kind", ""))
	if not KINDS.has(kind):
		errors.append("unknown kind \"%s\"" % kind)
		return errors
	if kind == KIND_BOSS:
		if int(def.get("floor", 0)) < 1:
			errors.append("a boss layout needs a floor >= 1")
	elif def.has("floor"):
		errors.append("only boss layouts may carry a floor")
	var raw: Variant = def.get("obstacles", null)
	if not (raw is Array):
		errors.append("obstacles must be an array")
		return errors
	var obstacles: Array = raw
	for i in obstacles.size():
		errors.append_array(_obstacle_errors(obstacles[i], i, kind))
	if not errors.is_empty():
		return errors  # the flood fill assumes well-formed, in-zone obstacles
	errors.append_array(_connectivity_errors(obstacles))
	return errors


## The obstacle footprints of a layout as conservative circles
## [{center: Vector2, radius: float}] — pillars exact, blocks circumscribed (covers
## any rotation). For placement keep-outs (StrataCore) and blocked() queries.
static func footprints(def: Dictionary) -> Array:
	var out: Array = []
	for obs: Dictionary in def.get("obstacles", []):
		var pos: Array = obs.get("pos", [0.0, 0.0])
		var center := Vector2(float(pos[0]), float(pos[1]))
		if str(obs.get("kind", "")) == OB_PILLAR:
			out.append({"center": center,
				"radius": float(obs.get("radius", DEFAULT_PILLAR_RADIUS))})
		else:
			var size: Array = obs.get("size", [1.0, 1.0])
			out.append({"center": center,
				"radius": Vector2(float(size[0]), float(size[1])).length() * 0.5})
	return out


## True when `p` sits within `margin` of any footprint circle — the cheap
## point-vs-obstacle query for spawn/hazard/prop placement.
static func blocked(footprints_arr: Array, p: Vector2, margin: float) -> bool:
	for fp: Dictionary in footprints_arr:
		var r := float(fp["radius"]) + margin
		if p.distance_squared_to(fp["center"]) < r * r:
			return true
	return false


# --- Per-obstacle rules -------------------------------------------------------------

static func _obstacle_errors(raw: Variant, index: int, kind: String) -> Array[String]:
	var errors: Array[String] = []
	var tag := "obstacles[%d]" % index
	if not (raw is Dictionary):
		errors.append("%s must be an object" % tag)
		return errors
	var obs: Dictionary = raw
	var ob_kind := str(obs.get("kind", ""))
	if ob_kind != OB_PILLAR and ob_kind != OB_BLOCK:
		errors.append("%s has unknown kind \"%s\"" % [tag, ob_kind])
		return errors
	var pos: Variant = obs.get("pos", null)
	if not _is_vec2_array(pos):
		errors.append("%s needs pos [x, z]" % tag)
		return errors
	var x := float(pos[0])
	var z := float(pos[1])
	var circ_radius: float  # circumscribed circle, for the boss-band rule
	var min_z: float        # southmost reach, for the door-strip rule
	if ob_kind == OB_PILLAR:
		var r := float(obs.get("radius", DEFAULT_PILLAR_RADIUS))
		if r <= 0.0:
			errors.append("%s pillar radius must be > 0" % tag)
			return errors
		circ_radius = r
		min_z = z - r
		if absf(x) + r > INTERIOR_HALF + EPS or absf(z) + r > INTERIOR_HALF + EPS:
			errors.append("%s pillar footprint leaves the +-%.0f interior" % [tag, INTERIOR_HALF])
	else:
		var size: Variant = obs.get("size", null)
		if not _is_vec2_array(size):
			errors.append("%s block needs size [w, d]" % tag)
			return errors
		var w := float(size[0])
		var d := float(size[1])
		if w <= 0.0 or d <= 0.0:
			errors.append("%s block size must be > 0" % tag)
			return errors
		circ_radius = Vector2(w, d).length() * 0.5
		var rot := deg_to_rad(float(obs.get("rot", 0.0)))
		min_z = INF
		for corner: Vector2 in _block_corners(Vector2(x, z), w, d, rot):
			min_z = minf(min_z, corner.y)
			if absf(corner.x) > INTERIOR_HALF + EPS or absf(corner.y) > INTERIOR_HALF + EPS:
				errors.append("%s block corner leaves the +-%.0f interior (%s)"
					% [tag, INTERIOR_HALF, corner])
				break
	# Door strip: the footprint must not reach z <= -20 (full width, all kinds).
	if min_z <= DOOR_STRIP_Z + EPS:
		errors.append("%s reaches the door strip (z <= %.0f)" % [tag, DOOR_STRIP_Z])
	# Player spawn keep-out (all kinds; exact edge distance, so long walls far from
	# the spawn don't false-positive on a circumscribed circle).
	if _edge_distance(obs, SPAWN_POINT) < SPAWN_CLEAR_RADIUS - EPS:
		errors.append("%s intrudes on the spawn keep-out (r=%.0f around %s)"
			% [tag, SPAWN_CLEAR_RADIUS, SPAWN_POINT])
	if kind == KIND_REPRIEVE \
			and _edge_distance(obs, WELLSPRING_POINT) < WELLSPRING_CLEAR_RADIUS - EPS:
		errors.append("%s intrudes on the Wellspring clearing (r=%.0f around %s)"
			% [tag, WELLSPRING_CLEAR_RADIUS, WELLSPRING_POINT])
	if kind == KIND_BOSS and _band_distance(Vector2(x, z)) < circ_radius - EPS:
		errors.append("%s intrudes on the boss band (|x| <= %.0f, z in [%.0f, %.0f])"
			% [tag, BOSS_BAND_HALF_X, BOSS_BAND_Z_MIN, BOSS_BAND_Z_MAX])
	return errors


## Exact distance from a point to a WELL-FORMED obstacle's footprint edge (<= 0 when
## inside). Pillars: circle distance; blocks: rotated-rect distance.
static func _edge_distance(obs: Dictionary, p: Vector2) -> float:
	var pos: Array = obs["pos"]
	var dx := p.x - float(pos[0])
	var dz := p.y - float(pos[1])
	if str(obs["kind"]) == OB_PILLAR:
		return Vector2(dx, dz).length() - float(obs.get("radius", DEFAULT_PILLAR_RADIUS))
	var size: Array = obs["size"]
	var a := deg_to_rad(float(obs.get("rot", 0.0)))
	var lx := dx * cos(a) - dz * sin(a)
	var lz := dx * sin(a) + dz * cos(a)
	var ox := maxf(absf(lx) - float(size[0]) * 0.5, 0.0)
	var oz := maxf(absf(lz) - float(size[1]) * 0.5, 0.0)
	return Vector2(ox, oz).length()


## Distance from a point to the boss clear band's rectangle (0 when inside).
static func _band_distance(p: Vector2) -> float:
	var dx := maxf(absf(p.x) - BOSS_BAND_HALF_X, 0.0)
	var dz := maxf(maxf(p.y - BOSS_BAND_Z_MAX, BOSS_BAND_Z_MIN - p.y), 0.0)
	return Vector2(dx, dz).length()


static func _is_vec2_array(v: Variant) -> bool:
	if not (v is Array) or (v as Array).size() != 2:
		return false
	for e: Variant in (v as Array):
		if not (e is float or e is int):
			return false
	return true


## The 4 world-space corners of a rotated block footprint (x/z as Vector2.x/y).
## Rotation matches a node's rotation_degrees.y: local (lx, lz) -> world
## (lx cos a + lz sin a, -lx sin a + lz cos a).
static func _block_corners(center: Vector2, w: float, d: float, rot: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var ca := cos(rot)
	var sa := sin(rot)
	for local: Vector2 in [Vector2(w * 0.5, d * 0.5), Vector2(-w * 0.5, d * 0.5),
			Vector2(w * 0.5, -d * 0.5), Vector2(-w * 0.5, -d * 0.5)]:
		out.append(center + Vector2(local.x * ca + local.y * sa,
			-local.x * sa + local.y * ca))
	return out


# --- Flood-fill path guarantee --------------------------------------------------------
# Rasterize the EXACT obstacle shapes (+GRID_MARGIN player padding) onto a 1 m grid of
# cell centres over the interior, then BFS from the spawn cell: the door-line cell must
# be reached, no sealed open pocket may exceed MAX_POCKET_CELLS, and the reachable
# region must cover REACHABLE_MIN_FRACTION of all open cells.

static func _connectivity_errors(obstacles: Array) -> Array[String]:
	var errors: Array[String] = []
	var w := GRID_MAX - GRID_MIN + 1
	var open := PackedByteArray()
	open.resize(w * w)
	var open_count := 0
	for gx in range(GRID_MIN, GRID_MAX + 1):
		for gz in range(GRID_MIN, GRID_MAX + 1):
			if not _cell_blocked(float(gx), float(gz), obstacles):
				open[_cell_index(gx, gz)] = 1
				open_count += 1
	var spawn := Vector2i(int(SPAWN_POINT.x), int(SPAWN_POINT.y))
	if open[_cell_index(spawn.x, spawn.y)] == 0:
		errors.append("the spawn cell %s is blocked" % spawn)  # unreachable given the keep-out rule
		return errors
	# BFS (4-connected) from the spawn.
	var reached := PackedByteArray()
	reached.resize(w * w)
	var queue: Array[Vector2i] = [spawn]
	reached[_cell_index(spawn.x, spawn.y)] = 1
	var reached_count := 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + step
			if n.x < GRID_MIN or n.x > GRID_MAX or n.y < GRID_MIN or n.y > GRID_MAX:
				continue
			var idx := _cell_index(n.x, n.y)
			if open[idx] == 1 and reached[idx] == 0:
				reached[idx] = 1
				reached_count += 1
				queue.append(n)
	if open[_cell_index(DOOR_CELL.x, DOOR_CELL.y)] == 0 \
			or reached[_cell_index(DOOR_CELL.x, DOOR_CELL.y)] == 0:
		errors.append("the spawn cannot reach the door line at %s" % DOOR_CELL)
	if float(reached_count) < REACHABLE_MIN_FRACTION * float(open_count):
		errors.append("only %d of %d open cells reachable from the spawn (< %.0f%%)"
			% [reached_count, open_count, REACHABLE_MIN_FRACTION * 100.0])
	var pocket := _largest_pocket(open, reached, w)
	if pocket > MAX_POCKET_CELLS:
		errors.append("a sealed pocket of %d cells (> %d) is unreachable from the spawn"
			% [pocket, MAX_POCKET_CELLS])
	return errors


## The largest connected component of open-but-unreachable cells (a sealed pocket).
static func _largest_pocket(open: PackedByteArray, reached: PackedByteArray, w: int) -> int:
	var seen := PackedByteArray()
	seen.resize(w * w)
	var largest := 0
	for gx in range(GRID_MIN, GRID_MAX + 1):
		for gz in range(GRID_MIN, GRID_MAX + 1):
			var idx := _cell_index(gx, gz)
			if open[idx] == 0 or reached[idx] == 1 or seen[idx] == 1:
				continue
			var size := 0
			var queue: Array[Vector2i] = [Vector2i(gx, gz)]
			seen[idx] = 1
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				size += 1
				for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
						Vector2i(0, 1), Vector2i(0, -1)]:
					var n := c + step
					if n.x < GRID_MIN or n.x > GRID_MAX or n.y < GRID_MIN or n.y > GRID_MAX:
						continue
					var nidx := _cell_index(n.x, n.y)
					if open[nidx] == 1 and reached[nidx] == 0 and seen[nidx] == 0:
						seen[nidx] = 1
						queue.append(n)
			largest = maxi(largest, size)
	return largest


static func _cell_index(gx: int, gz: int) -> int:
	return (gx - GRID_MIN) * (GRID_MAX - GRID_MIN + 1) + (gz - GRID_MIN)


## Whether a grid cell centre sits within GRID_MARGIN of any obstacle's EXACT shape
## (pillars as circles, blocks as rotated rectangles — not the conservative circles).
static func _cell_blocked(x: float, z: float, obstacles: Array) -> bool:
	for obs: Dictionary in obstacles:
		var pos: Array = obs["pos"]
		var dx := x - float(pos[0])
		var dz := z - float(pos[1])
		if str(obs["kind"]) == OB_PILLAR:
			var r := float(obs.get("radius", DEFAULT_PILLAR_RADIUS)) + GRID_MARGIN
			if dx * dx + dz * dz <= r * r:
				return true
		else:
			var size: Array = obs["size"]
			var a := deg_to_rad(float(obs.get("rot", 0.0)))
			# world -> block-local (inverse of the corner transform above)
			var lx := dx * cos(a) - dz * sin(a)
			var lz := dx * sin(a) + dz * cos(a)
			var ox := maxf(absf(lx) - float(size[0]) * 0.5, 0.0)
			var oz := maxf(absf(lz) - float(size[1]) * 0.5, 0.0)
			if ox * ox + oz * oz <= GRID_MARGIN * GRID_MARGIN:
				return true
	return false
