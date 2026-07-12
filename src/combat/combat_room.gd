extends Node3D
## One dungeon room of a LIVE run (vertical slice, PRD §12 milestone 3).
##
## The feel-gate sandbox (feel_room.gd) respawns waves forever; this room spawns ONE
## wave sized by where we are in the run, drops loot into the Ledger, and signals up
## to game.gd — it never touches RunState itself (the orchestrator owns run flow;
## signals down / calls up within the game scene tree).
##
## Lifecycle: game.gd calls setup(...) before adding to the tree → wave spawns →
## last kill emits `cleared` → game decides; if the run continues it calls
## present_doors() (1-2 sigil doors — design/run-structure.md) or, after a boss,
## open_exit() (a single plain portal) → player steps through → `exit_entered`.
## Boss rooms spawn the floor's data-driven boss (data/bosses/, design/bosses/
## floor-1-boss.md) — or, on floors without an authored def, the placeholder boss +
## escorts — and pay the boss bounty either way.
##
## The INCOMING door (the sigil the player chose to enter here) is passed to setup():
## `reprieve` makes this a breather room (no wave, a Wellspring instead), `peril` makes
## the wave elite (runtime stat mults over the exports — never the .tscn). What THIS
## room PAYS on clear is decided by game.gd from that same incoming door.

const ENEMY_BRUTE := preload("res://scenes/combat/enemy_dummy.tscn")
const ENEMY_SKIRMISHER := preload("res://scenes/combat/enemy_skirmisher.tscn")
const ENEMY_ARCHER := preload("res://scenes/combat/enemy_archer.tscn")
const ENEMY_SLAMMER := preload("res://scenes/combat/enemy_slammer.tscn")
const ENEMY_CHARGER := preload("res://scenes/combat/enemy_charger.tscn")
const ENEMY_BOSS := preload("res://scenes/combat/enemy_boss.tscn")

## WaveCore type-id → scene. compose() only ever emits ids in WaveCore.TYPES.
const ENEMY_SCENES := {
	WaveCore.TYPE_BRUTE: ENEMY_BRUTE,
	WaveCore.TYPE_SKIRMISHER: ENEMY_SKIRMISHER,
	WaveCore.TYPE_ARCHER: ENEMY_ARCHER,
	WaveCore.TYPE_SLAMMER: ENEMY_SLAMMER,
	WaveCore.TYPE_CHARGER: ENEMY_CHARGER,
}

## Placeholder until real per-floor bosses land (PRD §7.7 — bosses are human-gated).
const BOSS_ID := "boss-placeholder"

## The spawned boss's identity: the data/bosses/ def id on floors with an authored
## def (floor 1 = den-warden, 2026-07-10), else the placeholder fallback. game.gd
## reads it for room_cleared/boss_killed; set in _spawn_data_boss.
var boss_id: String = BOSS_ID

const PLAYER_SPAWN := Vector3(0, 0, 18)  # south edge; the wave scatters around centre

# FEEL knobs — same names as feel_room.gd, so the F1 tuning panel works in-run too.
@export var enemy_count: int = 3         # FEEL: base enemies in a combat room (scaled by floor+room)
@export var respawn_delay: float = 0.9   # FEEL: beat between the last kill and the exit opening (s)
@export var wave_beat: float = 1.0       # FEEL: pause between a cleared wave and the next (s)
@export var wave_spawn_telegraph: float = 0.6  # FEEL: spawn-marker warn time before enemies appear (s)
@export var shake_on_hit: float = 0.35   # FEEL: camera kick (m) when the player takes a hit
@export var spawn_radius: float = 16.0   # FEEL: how far out around the room the wave scatters (m)
@export var spawn_jitter: float = 3.0    # FEEL: random wobble on each spawn point (m)

# Drop economy — placeholder numbers (economy tuning is an OPEN question, PRD §13).
# Rebalanced 2026-07-10 against tools/economy_sim.gd (sink-saturation pass) — that
# tool's income constants MIRROR these by hand; keep them in sync when dialing.
@export var gold_per_enemy_min: int = 0
@export var gold_per_enemy_max: int = 1
@export var ore_drop_chance: float = 0.01  # Resonance Ore per kill (weapons sink, PRD §7.10)
@export var boss_gold: int = 15
@export var boss_shards: int = 1         # Knowledge Shards per stage boss (PRD §7.10)
@export var boss_ore: int = 1            # guaranteed Resonance Ore per boss

signal cleared        # the wave is down; the orchestrator decides what happens next
signal exit_entered   # the player stepped into the open exit portal
signal player_died    # HP hit 0 in this room
signal artifact_entered  # the player walked into the codex artifact (final chamber) — dissolve + run end

# Where in the run this room sits — set via setup() before entering the tree.
var floor_num: int = 1
var room_index: int = 1
var rooms_this_floor: int = 1
var kind: String = RunFlow.KIND_COMBAT

# The door that led INTO this room {sigil, peril} ({} for a floor's first room).
var incoming_door: Dictionary = {}
var _peril: bool = false      # elite wave (incoming_door.peril)
var _reprieve: bool = false   # breather room: no wave, a Wellspring instead

# The floor's stratum profile (design/dungeon-strata.md): environment palette, props,
# and the hazard plan. Empty {} outside a live run (the sandbox) → default look, no
# hazards. Passed by game.gd from _floor_profile(floor).
var _profile: Dictionary = {}

var _enemies: Array[EnemyDummy] = []
# Sequential waves (design 2026-07-06): a combat room runs 2-3 waves; the room only
# CLEARS after the last wave falls. Empty for boss/reprieve rooms (they don't wave).
var _waves: Array = []          # list of Array[String] WaveCore type-ids
var _wave_index: int = 0
var _cleared: bool = false
var _hazard_ids: Array[String] = []  # the strata hazards spawned this room (design/dungeon-strata.md)
# The room-layout pick (PRD §7.6, 2026-07-12): {} = no layout data or a validation
# failure → the .tscn's authored obstacles stay (graceful degrade, same philosophy as
# game.gd._floor_profile's clamp). The footprints feed hazard/prop keep-outs + spawn nudges.
var _layout: Dictionary = {}
var _layout_footprints: Array = []
var _door_chosen: bool = false  # first door walked wins — no backtracking
var _last_hp: int = Player.MAX_HEALTH
# Hades quit-gate (design 2026-07-07): true once the player has taken a hit IN THIS ROOM.
# Never reset within the room — the ESC menu may forfeit / quit only when the room is
# cleared OR the player is still untouched (can_menu_quit).
var _damage_taken: bool = false
# Passive Attunement run-hooks (bible, PRD §7.4), set from the save at setup:
var _find_mult: float = 1.0     # Attunement: Dust/Ore find-rate multiplier (per-kill ore roll)
var _recovery_pct: float = 0.0  # Recovery: % of missing HP healed on room clear
var _hud: RunHud  # the in-run HUD (design/ui-hud.md) — chip / HP / echoes / abilities / boss

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _portal: Area3D = $ExitPortal


func setup(p_floor: int, p_room: int, p_rooms_this_floor: int, p_kind: String,
		p_incoming: Dictionary = {}, p_profile: Dictionary = {}) -> void:
	floor_num = p_floor
	room_index = p_room
	rooms_this_floor = p_rooms_this_floor
	kind = p_kind
	incoming_door = p_incoming.duplicate()
	_profile = p_profile
	# Reprieve/peril come from the CHOSEN sigil, never from RunFlow position; a boss room
	# is always a straight fight (its incoming door is the plain boss door).
	if kind != RunFlow.KIND_BOSS:
		_reprieve = str(incoming_door.get("sigil", "")) == DoorCore.SIGIL_REPRIEVE
		_peril = bool(incoming_door.get("peril", false))


func _ready() -> void:
	_rig.set_target(_player)
	_player.position = PLAYER_SPAWN
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(func() -> void: player_died.emit())
	_portal.visible = false
	_portal.monitoring = false
	_portal.body_entered.connect(_on_portal_body_entered)
	# Salvage echo (design/run-structure.md): heal on ore/dust pickup mid-run. The room hears
	# the Ledger through the bus; the connection auto-drops when the room frees (no cross-room leak).
	EventBus.resource_changed.connect(_on_resource_changed)
	# Room layout (PRD §7.6): swap the authored obstacles for this room's seeded pick
	# from data/layouts/ — BEFORE the environment pass, so the built obstacles get the
	# stratum tint + toon treatment exactly like the authored ones.
	_build_layout()
	# Strata (design/dungeon-strata.md): paint the environment + scatter props on EVERY
	# room kind; spawn hazards on combat rooms only (reprieve = breather, boss = clean
	# arena this slice). Enemy/telegraph colours are NEVER touched — the readability guard.
	_apply_environment()
	_spawn_props()
	if kind == RunFlow.KIND_COMBAT and not _reprieve:
		_spawn_hazards()
	# The in-run HUD (design/ui-hud.md) — one code-built Control on the HUD layer.
	_hud = RunHud.new()
	$HUD.add_child(_hud)
	_hud.setup(_player)
	var hud_kind := HudCore.KIND_REPRIEVE if _reprieve else kind
	_hud.configure_room(floor_num, room_index, rooms_this_floor, hud_kind, _peril)
	_hud.set_hint("Clear the room")
	# Configure this room's FRESH player instance, in order: the equipped weapon
	# (baseline kit), then the run's echoes on top, then carried-over HP (rooms
	# must not free-heal).
	var combat: Dictionary = SaveManager.state["combat"]
	var weapon_id := str(combat.get("current_weapon", "sword"))
	if WeaponCore.defs().has(weapon_id):
		WeaponCore.apply_to_player(_player, WeaponCore.defs()[weapon_id],
			WeaponCore.flat_level(combat, weapon_id))
	else:
		push_error("CombatRoom: unknown current_weapon \"%s\" — using the base kit" % weapon_id)
	# Passive Attunements (bible, PRD §7.4) — the persistent baseline UNDER echoes. Apply
	# order: base feel exports → weapon → ATTUNEMENTS → echoes. Stat-kind attunements ride
	# EchoCore's SAME mod math (no duplicate engine); the non-stat kinds set player/room
	# hooks (Resilience DR, Resonance Flow cooldown mult, the find-rate + recovery caches).
	var attn: Dictionary = combat.get("attunements", {})
	var adefs := AttunementsCore.defs()
	var amods := AttunementsCore.stat_mods(attn, adefs)
	if not amods.is_empty():
		EchoCore.apply_to_player(_player, {"id": "attunements", "mods": amods})
	_player.flat_damage_reduction = AttunementsCore.damage_reduction(attn, adefs)
	_player.ability_cooldown_mult = AttunementsCore.ability_cooldown_mult(attn, adefs)
	_find_mult = AttunementsCore.find_rate_mult(attn, adefs)
	_recovery_pct = AttunementsCore.heal_on_clear_pct(attn, adefs)
	EchoCore.apply_all_to_player(_player, RunState.echoes)
	if RunState.player_health > 0:
		_player.restore_health(RunState.player_health)
	# Rebaseline the hit tracker AFTER HP setup: the restore above emits health_changed
	# with a carried-wound value, which must NOT count as damage taken this room.
	_last_hp = _player.health
	_damage_taken = false
	# Seed the HUD with the player's starting HP + this run's echo picks (health_changed
	# already fired during the player's own _ready, before the HUD existed to hear it).
	_hud.set_hp(_player.health, _player.max_health)
	_hud.refresh_echoes()
	_spawn_wave()
	# Same live feel-tuning panel as the sandbox (F1) — dials apply to THIS room's
	# instances plus the shared static knobs (hitstop, crowd rules).
	var panel := TuningPanel.new()
	$HUD.add_child(panel)
	panel.setup(_player, _rig, self)


# --- Strata (design/dungeon-strata.md) -------------------------------------------
# Environment paint + prop dressing + the hazard plan, all off the floor's stratum
# profile (StrataCore, pure/seeded). The materials + Environment sub-resource are
# resource_local_to_scene, so mutating them here affects only THIS room instance.

func _apply_environment() -> void:
	var env := StrataCore.environment_of(_profile)
	var we := $WorldEnvironment as WorldEnvironment
	if we != null and we.environment != null:
		var e := we.environment
		e.background_color = env["background_color"]
		e.ambient_light_color = env["ambient_color"]
		e.ambient_light_energy = float(env["ambient_energy"])
		e.fog_enabled = bool(env["fog_enabled"])
		e.fog_light_color = env["fog_color"]
		e.fog_density = float(env["fog_density"])
	var light := $DirectionalLight3D as DirectionalLight3D
	if light != null:
		light.light_color = env["light_color"]
		light.light_energy = float(env["light_energy"])
	# Style layer (design/asset-pipeline.md §C): ground/wall/obstacles render through the
	# shared toon shader, tinted by this stratum's ramp. ONE material per role, shared by
	# its meshes — retinting a role still repaints its siblings (previous behaviour), and
	# each room instance builds fresh materials (the resource_local_to_scene guarantee by
	# other means). NO outline on environment geometry. Retint later via
	# StyleMaterials.set_tint (which replaced the old _set_albedo).
	var ramp := StyleCore.ramp_stops(env)
	($Floor/Mesh as MeshInstance3D).set_surface_override_material(0,
		StyleMaterials.toon_material(env["ground_color"], ramp, false))
	var wall_mat := StyleMaterials.toon_material(env["wall_color"], ramp, false)
	for wall: Variant in [$WallN/Mesh, $WallS/Mesh, $WallE/Mesh, $WallW/Mesh]:
		(wall as MeshInstance3D).set_surface_override_material(0, wall_mat)
	var obstacle_mat := StyleMaterials.toon_material(env["obstacle_color"], ramp, false)
	for obstacle in $Obstacles.get_children():
		var m := (obstacle as Node).get_node_or_null("Mesh") as MeshInstance3D
		if m != null:
			m.set_surface_override_material(0, obstacle_mat)


# --- Room layout (PRD §7.6, design/dungeon-strata.md § Room layouts) ---------------
# The seeded pick from data/layouts/ replaces the .tscn's authored Obstacles children
# at runtime; with no layout data (or a validation failure — a CONTENT bug, warned
# loudly) the authored obstacles stay. Built obstacles mirror the .tscn's setup
# (StaticBody3D layer 4 / mask 0 + "Mesh" + CollisionShape3D), so _apply_environment's
# generic $Obstacles sweep tints + toon-converts BOTH paths identically.

const OBSTACLE_Y := 1.5        # obstacle bodies sit at the .tscn's height
const PILLAR_HEIGHT := 4.0     # mirrors the authored PillarMesh/PillarShape
const BLOCK_HEIGHT := 3.0      # mirrors the authored BlockMesh/BlockShape

func _build_layout() -> void:
	var lay := planned_layout()
	if lay.is_empty():
		return  # no layout data for this kind/floor — keep the authored obstacles
	var errors := LayoutCore.validate(lay)
	if not errors.is_empty():
		for e in errors:
			push_warning("CombatRoom: layout \"%s\": %s — keeping the authored obstacles"
				% [str(lay.get("id", "?")), e])
		return
	_layout = lay
	_layout_footprints = LayoutCore.footprints(lay)
	var holder := $Obstacles as Node3D
	for child in holder.get_children():
		holder.remove_child(child)
		child.free()  # freed NOW, not queued — _apply_environment sweeps $Obstacles next
	for obs: Dictionary in lay["obstacles"]:
		holder.add_child(_build_obstacle(obs))


func _build_obstacle(obs: Dictionary) -> StaticBody3D:
	var body := StaticBody3D.new()
	var pos: Array = obs["pos"]
	body.position = Vector3(float(pos[0]), OBSTACLE_Y, float(pos[1]))
	body.collision_layer = 4
	body.collision_mask = 0
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"  # _apply_environment finds the tintable mesh by this name
	var shape := CollisionShape3D.new()
	if str(obs["kind"]) == LayoutCore.OB_PILLAR:
		var r := float(obs.get("radius", LayoutCore.DEFAULT_PILLAR_RADIUS))
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = PILLAR_HEIGHT
		mesh.mesh = cm
		var cs := CylinderShape3D.new()
		cs.radius = r
		cs.height = PILLAR_HEIGHT
		shape.shape = cs
	else:
		var size: Array = obs["size"]
		var bm := BoxMesh.new()
		bm.size = Vector3(float(size[0]), BLOCK_HEIGHT, float(size[1]))
		mesh.mesh = bm
		var bs := BoxShape3D.new()
		bs.size = bm.size
		shape.shape = bs
		body.rotation_degrees = Vector3(0.0, float(obs.get("rot", 0.0)), 0.0)
	body.add_child(mesh)
	body.add_child(shape)
	return body


## This room's layout pick (deterministic in the run seed + floor + room coords, like
## planned_hazards). The shuffle seed deliberately omits room_index — LayoutCore salts
## the per-floor shuffle itself, which is what makes combat layouts non-repeating
## within a floor. Exposed so the smoke can recompute the SAME pick and assert it.
func planned_layout() -> Dictionary:
	var lkind := LayoutCore.KIND_COMBAT
	if kind == RunFlow.KIND_BOSS:
		lkind = LayoutCore.KIND_BOSS
	elif _reprieve:
		lkind = LayoutCore.KIND_REPRIEVE
	var base := int(RunState.run.get("seed", 0)) if RunState.in_run() else 0
	return LayoutCore.pick(DataLoader.load_domain("layouts"), lkind, floor_num,
		room_index, hash([base, "strata", "layout"]))


## The number of obstacles standing in this room (layout-built or authored fallback).
## For the smoke's determinism assert.
func obstacle_count() -> int:
	return ($Obstacles as Node3D).get_child_count()


## The layout obstacle footprints inflated by a safety margin — HARD keep-out circles
## for hazard/prop scatter. Empty on the authored-fallback path (today's behaviour).
func _layout_keep_outs() -> Array:
	var out: Array = []
	for fp: Dictionary in _layout_footprints:
		out.append({"center": fp["center"], "radius": float(fp["radius"]) + 1.0})
	return out


func _spawn_props() -> void:
	var ids: Array = _profile.get("props", [])
	if ids.is_empty():
		return
	# Props ride the stratum ramp too (StyleMaterials via StrataProps.build).
	var ramp := StyleCore.ramp_stops(StrataCore.environment_of(_profile))
	for entry: Dictionary in StrataCore.prop_plan(ids, _strata_seed("props"),
			StrataCore.PROP_HALF_EXTENT, Vector2(0.0, 18.0), StrataCore.KEEP_OUT_SPAWN,
			StrataCore.PROP_MIN_SPACING, _layout_keep_outs()):
		var node := StrataProps.build(str(entry["id"]), ramp)
		if node == null:
			continue  # unknown id (warned in StrataProps) — never crash a room
		var p: Vector3 = entry["pos"]
		node.position = Vector3(p.x, 0.0, p.z)
		add_child(node)


func _spawn_hazards() -> void:
	var plan := planned_hazards()
	_hazard_ids = plan
	if plan.is_empty():
		return
	var defs := DataLoader.load_domain("hazards")
	var pts := StrataCore.placement_points(plan.size(), _strata_seed("place"),
		StrataCore.HALF_EXTENT, Vector2(0.0, 18.0), StrataCore.KEEP_OUT_SPAWN,
		StrataCore.MIN_SPACING, _layout_keep_outs())
	for i in plan.size():
		var id := plan[i]
		if not defs.has(id):
			push_error("CombatRoom: hazard plan named unknown hazard \"%s\"" % id)
			continue
		var hz := Hazard.new()
		hz.position = pts[i]
		hz.configure(defs[id], _strata_seed("cfg-" + id + str(i)))
		hz.target = _player
		add_child(hz)


## Strata seed: the run seed salted per concern + this room's coordinates, so the plan
## is reproducible on a checkpoint resume (regenerates by seed) and in the smoke. Mirrors
## _wave_seed's base (falls back to a fixed seed outside a live run).
func _strata_seed(salt: String) -> int:
	var base := int(RunState.run.get("seed", 0)) if RunState.in_run() else 0
	return hash([base, "strata", salt, floor_num, room_index])


## This room's hazard plan (deterministic in the run seed + room coords). Exposed so the
## smoke can recompute the SAME plan and assert the spawned count matches.
func planned_hazards() -> Array[String]:
	return StrataCore.hazard_plan(_profile, room_index, rooms_this_floor,
		kind == RunFlow.KIND_COMBAT and not _reprieve, _strata_seed("plan"))


## The number of hazards this room actually spawned. For the smoke's determinism assert.
func hazard_count() -> int:
	return _hazard_ids.size()


## The environment background colour applied to this room (post-strata). For the smoke.
func environment_background() -> Color:
	var we := $WorldEnvironment as WorldEnvironment
	return we.environment.background_color if we != null and we.environment != null else Color.BLACK


# --- Wave ---------------------------------------------------------------------

func _spawn_wave() -> void:
	if _reprieve:
		# A breather: no fight. Spawn the Wellspring and clear at once so game.gd shows
		# the next doors; the heal is the reward, taken by touching the pool.
		_spawn_wellspring()
		_cleared = true
		_hud.mark_cleared()
		cleared.emit.call_deferred()
		_hud.set_hint("Breather — touch the Wellspring, then choose a door")
		return
	if kind == RunFlow.KIND_BOSS:
		# Boss rooms are a single staged fight — no waves. A floor with an authored def
		# in data/bosses/ gets the real data-driven boss (design/bosses/floor-1-boss.md:
		# a clean arena, no escorts, dormant arena vents); floors without one keep the
		# stats-pumped placeholder + escort pair unchanged.
		var bdef := BossCore.def_for_floor(DataLoader.load_domain("bosses"), floor_num)
		if not bdef.is_empty():
			var errors := BossCore.validate(bdef)
			if errors.is_empty():
				_spawn_data_boss(bdef)
				return
			for e in errors:
				push_error("CombatRoom: boss def \"%s\": %s" % [str(bdef.get("id", "?")), e])
			# fall through to the placeholder — a broken def must never brick a run
		var boss := _spawn_enemy(ENEMY_BOSS, Vector3(0, 1.0, -14))
		_hud.set_boss(boss)
		_spawn_enemy(ENEMY_SKIRMISHER, Vector3(-8, 1.0, -10))
		_spawn_enemy(ENEMY_SKIRMISHER, Vector3(8, 1.0, -10))
		return
	# Multi-wave combat room: compose the whole plan (pure/seeded WaveCore), then spawn
	# wave 0. Each wave's clear either spawns the next (after a beat) or, on the last,
	# emits `cleared` — all in _on_enemy_died. Peril mults ride _spawn_enemy, so every
	# wave's spawns get them.
	_waves = WaveCore.compose(floor_num, room_index, enemy_count, _wave_seed())
	_wave_index = 0
	_spawn_current_wave()


func _wave_seed() -> int:
	# Vary the mix per run (falls back to a fixed seed outside a live run).
	return int(RunState.run.get("seed", 0)) if RunState.in_run() else 0


func _spawn_current_wave() -> void:
	_update_wave_label()
	var wave: Array = _waves[_wave_index]
	for i in wave.size():
		_telegraph_then_spawn(_scene_for_id(str(wave[i])), _wave_spawn_pos(i, wave.size()))


## Flash a growing ground marker at the spawn point, then drop the enemy in — so a new
## wave READS before it can hit anyone. Guards a torn-down room (player died / quit).
func _telegraph_then_spawn(scene: PackedScene, pos: Vector3) -> void:
	CombatFX.ground_telegraph(self, pos, wave_spawn_telegraph, 1.2, Color(1.0, 0.85, 0.2))
	await get_tree().create_timer(wave_spawn_telegraph).timeout
	if not is_inside_tree() or _cleared:
		return
	_spawn_enemy(scene, pos)


func _scene_for_id(type_id: String) -> PackedScene:
	if ENEMY_SCENES.has(type_id):
		return ENEMY_SCENES[type_id]
	push_error("CombatRoom: unknown wave type \"%s\" — using the Brute" % type_id)
	return ENEMY_BRUTE


func _update_wave_label() -> void:
	# Wave progress now lives in the info chip (design/ui-hud.md), not the hint.
	_hud.set_wave(_wave_index, _waves.size())


func _spawn_enemy(scene: PackedScene, pos: Vector3) -> EnemyDummy:
	var enemy: EnemyDummy = scene.instantiate()
	enemy.position = pos
	enemy.target = _player
	# Peril = the elite-modifier stub (PRD §7.7): scale the exports at spawn, before
	# _ready reads max_hp — a runtime mod like WeaponCore/echoes, never a .tscn edit.
	if _peril:
		enemy.max_hp = DoorCore.peril_hp(enemy.max_hp)
		enemy.attack_damage = DoorCore.peril_damage(enemy.attack_damage)
	add_child(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	_enemies.append(enemy)
	return enemy


## Spawn a floor's data-driven boss (design/bosses/floor-1-boss.md): setup(def) runs
## BEFORE add_child (like the peril mults) so _ready reads the def's hp; the def's name
## labels the HUD boss bar; the arena's vent plates spawn DORMANT for its vent_call.
## Bounty / heal valve / echo pick / boss_killed all ride the same paths as before.
func _spawn_data_boss(def: Dictionary) -> void:
	boss_id = str(def["id"])
	var boss: EnemyBoss = ENEMY_BOSS.instantiate()
	boss.position = Vector3(0, 1.0, -14)
	boss.target = _player
	boss.setup(def)
	add_child(boss)
	boss.died.connect(_on_enemy_died.bind(boss))
	_enemies.append(boss)
	boss.set_arena_vents(_spawn_arena_vents(def.get("arena_vents", [])))
	_hud.set_boss(boss)
	_hud.set_boss_name(str(def["name"]))


## The boss arena's vent plates (floor-1-boss.md rule 4): REAL vent-plate hazards at
## the def's [x, z] spots, spawned DORMANT — they never self-cycle; only the boss's
## vent_call move fires them (phase 2). The boss room stays a clean arena otherwise
## (no random hazard scatter — the strata plan never runs here).
func _spawn_arena_vents(positions: Array) -> Array[Hazard]:
	var out: Array[Hazard] = []
	if positions.is_empty():
		return out
	var defs := DataLoader.load_domain("hazards")
	if not defs.has("vent-plate"):
		push_error("CombatRoom: arena vents need data/hazards/vent-plate.json")
		return out
	for i in positions.size():
		var p: Array = positions[i]
		if p.size() < 2:
			push_error("CombatRoom: arena_vents[%d] must be an [x, z] pair" % i)
			continue
		var hz := Hazard.new()
		hz.position = Vector3(float(p[0]), 0.0, float(p[1]))
		hz.configure(defs["vent-plate"], _strata_seed("boss-vent-%d" % i))
		hz.target = _player
		hz.set_dormant(true)
		add_child(hz)
		out.append(hz)
	return out


func _wave_spawn_pos(i: int, count: int) -> Vector3:
	# Scatter around the room centre (like feel_room), away from the south spawn.
	var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
	var radius := spawn_radius + randf_range(-spawn_jitter, spawn_jitter)
	var pos := Vector3(cos(angle) * radius, 1.0, sin(angle) * radius - 4.0)
	# Layout obstacles: never telegraph an enemy into a pillar/block. Cheap and dumb —
	# a handful of angle nudges, then accept the original point (never an infinite loop).
	if _layout_footprints.is_empty() \
			or not LayoutCore.blocked(_layout_footprints, Vector2(pos.x, pos.z), 1.0):
		return pos
	for nudge: float in [0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0]:
		var a := angle + nudge
		var p := Vector3(cos(a) * radius, 1.0, sin(a) * radius - 4.0)
		if not LayoutCore.blocked(_layout_footprints, Vector2(p.x, p.z), 1.0):
			return p
	return pos


func _on_enemy_died(enemy: EnemyDummy) -> void:
	# Mender's Rhythm echo (design/run-structure.md): heal a % of MISSING HP on EVERY kill —
	# before the wave/clear bookkeeping so it fires on all kills, not just the last.
	if is_instance_valid(_player) and _player.heal_on_kill_pct > 0.0:
		apply_missing_heal(_player.heal_on_kill_pct)
	Ledger.add("gold", float(randi_range(gold_per_enemy_min, gold_per_enemy_max)), "run-drop")
	# Attunement find-rate lifts the per-kill ore chance (mult 1.0 = unchanged).
	if randf() < ore_drop_chance * _find_mult:
		Ledger.add("resonance-ore", 1.0, "run-drop")
	_enemies.erase(enemy)
	if not _enemies.is_empty() or _cleared:
		return
	# The current wave is down. If a combat room has more waves, spawn the next after a
	# beat; the room only CLEARS (drops door/echo offers, boss loot) after the last one.
	if kind != RunFlow.KIND_BOSS and _wave_index + 1 < _waves.size():
		_advance_wave()
		return
	_cleared = true
	_hud.mark_cleared()
	# Recovery attunement (design/run-structure.md): heal a % of MISSING HP when a room is
	# cleared by fighting (combat + boss; reprieve breathers clear without this path). The
	# boss valve's 30% is added on top by game.gd — both are % of missing, as intended.
	if _recovery_pct > 0.0:
		apply_missing_heal(_recovery_pct)
	if kind == RunFlow.KIND_BOSS:
		Ledger.add("gold", float(boss_gold), "boss-drop")
		Ledger.add("knowledge-shards", float(boss_shards), "boss-drop")
		Ledger.add("resonance-ore", float(boss_ore), "boss-drop")
	cleared.emit()


## Wait a beat after a wave falls, then bring in the next one (its spawns telegraph).
func _advance_wave() -> void:
	_wave_index += 1
	await get_tree().create_timer(wave_beat).timeout
	if not is_inside_tree() or _cleared:
		return
	_spawn_current_wave()


## True once the room is fully cleared (last wave / boss down). For the headless smoke,
## which must drive multi-wave rooms to completion.
func is_cleared() -> bool:
	return _cleared


## Total waves this room runs (1 for boss/reprieve). Exposed for the smoke's assert.
func wave_total() -> int:
	return maxi(1, _waves.size())


# --- Exit & doors ----------------------------------------------------------------

## Boss rooms (and any plain continue) use the single scene portal — no choice.
func open_exit() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_portal.visible = true
	_portal.monitoring = true
	Sfx.play("door-open", _portal.global_position)
	_hud.set_hint("Exit open — step into the light")


func _on_portal_body_entered(body: Node3D) -> void:
	if body is Player:
		RunState.player_health = _player.health  # wounds carry into the next room
		exit_entered.emit()


## Door choice (design/run-structure.md): after a beat, open the offer's 1-2 sigil
## doors; walking into one commits it (no backtracking). `on_choose` gets the chosen
## door dict {sigil, peril}; the room then emits exit_entered as with the plain exit.
func present_doors(offer: Array, on_choose: Callable) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_portal.visible = false
	_portal.monitoring = false  # the scene's single portal is unused when doors are shown
	var xs := [0.0] if offer.size() == 1 else [-6.0, 6.0]
	for i in offer.size():
		_make_door(Vector3(float(xs[i]), 1.75, -23.0), offer[i], on_choose)
	Sfx.play("door-open", Vector3(0, 1.75, -23))
	_hud.set_hint("Choose a door — the sigil is what the next room pays")


func _make_door(pos: Vector3, door: Dictionary, on_choose: Callable) -> void:
	var area := Area3D.new()
	area.add_to_group("door_portal")
	area.set_meta("door", door)
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.3
	cyl.height = 3.5
	shape.shape = cyl
	area.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.3
	cm.bottom_radius = 1.3
	cm.height = 3.5
	mesh.mesh = cm
	mesh.material_override = _door_material(door)
	area.add_child(mesh)
	var label := Label3D.new()
	label.text = _door_label(door)
	label.position = Vector3(0, 2.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	area.add_child(label)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player and not _door_chosen:
			_door_chosen = true
			RunState.player_health = _player.health  # wounds carry into the next room
			on_choose.call(door)
			exit_entered.emit())
	add_child(area)


func _door_material(door: Dictionary) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	var col := Color(0.4, 0.85, 1.0)  # default portal blue
	match str(door.get("sigil", "")):
		DoorCore.SIGIL_REPRIEVE:
			col = Color(0.4, 1.0, 0.7)
		DoorCore.SIGIL_ECHO:
			col = Color(0.85, 0.6, 1.0)
		DoorCore.SIGIL_BOSS:
			col = Color(0.9, 0.3, 0.85)
	if bool(door.get("peril", false)):
		col = col.lerp(Color(1.0, 0.35, 0.2), 0.5)  # peril shoves it toward danger-red
	mat.albedo_color = Color(col.r, col.g, col.b, 0.35)
	mat.emission = col
	mat.emission_energy_multiplier = 2.0
	return mat


func _door_label(door: Dictionary) -> String:
	var sigil := str(door.get("sigil", ""))
	return sigil.capitalize() + (" ⚠" if bool(door.get("peril", false)) else "")


## A healing valve (design/run-structure.md Part 2): heal a % of MISSING hp through the
## real player API so RunState's carried HP stays correct. Returns the amount healed.
func apply_missing_heal(pct: float) -> int:
	var amount := DoorCore.heal_missing(_player.health, _player.max_health, pct)
	if amount > 0:
		_player.heal(amount)
	return amount


## Salvage echo hook: an in-run Resonance Ore / Dust pickup heals a % of MISSING HP. Fires on
## any increase to those two (the run-drop / boss-drop / door-reward reasons all flow through
## the Ledger's resource_changed). No-op without the echo (heal_on_pickup_pct defaults to 0).
func _on_resource_changed(id: String, old_amount: float, new_amount: float, _reason: String) -> void:
	if not is_instance_valid(_player) or _player.heal_on_pickup_pct <= 0.0:
		return
	if new_amount > old_amount and (id == "resonance-ore" or id == "resonance-dust"):
		apply_missing_heal(_player.heal_on_pickup_pct)


# --- Wellspring (Reprieve room) --------------------------------------------------

func _spawn_wellspring() -> void:
	var well := Area3D.new()
	well.add_to_group("wellspring")
	well.position = Vector3(0, 1.0, -2)
	well.collision_layer = 0
	well.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.8
	shape.shape = sph
	well.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.4
	sm.height = 2.8
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 1.0, 0.7)
	mat.albedo_color = Color(0.4, 1.0, 0.7, 0.55)
	mesh.mesh = sm
	mesh.material_override = mat
	well.add_child(mesh)
	var label := Label3D.new()
	label.text = "Wellspring"
	label.position = Vector3(0, 2.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	well.add_child(label)
	var spent := [false]  # one use; boxed so the lambda can flip it
	# The distance re-check rejects Godot's spurious first-frame body_entered (fired when
	# the area + a far-off body enter the tree the same frame) — heal only on real contact.
	well.body_entered.connect(func(body: Node3D) -> void:
		if body is Player and not spent[0] \
				and body.global_position.distance_to(well.global_position) < 2.5:
			spent[0] = true
			apply_missing_heal(DoorCore.WELLSPRING_HEAL_PCT)
			label.text = "Wellspring (spent)")
	add_child(well)


# --- Codex artifact (final chamber only) -----------------------------------------

## Raise the codex artifact pedestal (design 2026-07-07). In the FINAL floor's boss room,
## game.gd calls this after the boss valve (heal + guaranteed echo) resolves — a pedestal
## rises INSTEAD of the plain exit and is the ONLY way out. Walking into it dissolves Tycho
## and ends the run (emits `dissolved` on the bus + `artifact_entered` up to game.gd). The
## label shows the current shard count / max; this run's shard is granted on run_ended.
func open_artifact(shards: int, shards_max: int) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_spawn_artifact(shards, shards_max)
	_hud.set_hint("The codex artifact stands whole — step into it")


func _spawn_artifact(shards: int, shards_max: int) -> void:
	var artifact := Area3D.new()
	artifact.add_to_group("codex_artifact")
	artifact.position = Vector3(0, 1.4, -18)
	artifact.collision_layer = 0
	artifact.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.0
	shape.shape = sph
	artifact.add_child(shape)
	var mesh := MeshInstance3D.new()
	# Placeholder: an egg-ish prism, artifact-purple, glowing (the egg motif, bible §story).
	var pm := PrismMesh.new()
	pm.size = Vector3(1.6, 2.8, 1.6)
	mesh.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.75, 0.45, 1.0)
	mat.albedo_color = Color(0.5, 0.3, 0.8)
	mesh.material_override = mat
	artifact.add_child(mesh)
	var label := Label3D.new()
	label.text = "Codex: %d/%d" % [shards, shards_max]
	label.position = Vector3(0, 2.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	artifact.add_child(label)
	var spent := [false]  # one use; the dissolve ends the run
	# Distance re-check rejects Godot's spurious first-frame body_entered (as the Wellspring).
	artifact.body_entered.connect(func(body: Node3D) -> void:
		if body is Player and not spent[0] \
				and body.global_position.distance_to(artifact.global_position) < 3.0:
			spent[0] = true
			RunState.player_health = _player.health  # (unused after town return, kept for parity)
			_dissolve_player()
			EventBus.dissolved.emit()
			artifact_entered.emit())
	add_child(artifact)
	# global_position is only valid once the artifact is in the tree (add_child above).
	Sfx.play("door-open", artifact.global_position)


## Placeholder dissolve FX (design 2026-07-07): a brief tinted burst where Tycho stands +
## hide his mesh. Reuses the death-FX shard burst; ~0.5s, purely cosmetic (the run has
## already ended at the artifact). No FEEL numbers — placeholder until the painterly pass.
func _dissolve_player() -> void:
	if not is_instance_valid(_player):
		return
	CombatFX.death_burst(self, _player.global_position, Color(0.75, 0.45, 1.0))
	_player.visible = false


# --- Echo offer -----------------------------------------------------------------

## Called by the orchestrator on an echo-door clear or after a boss kill: pause, offer
## 3 echoes, apply the pick to this room's player, then run `on_done` (which shows the
## next doors, or opens the boss exit). `on_pick` records the pick on RunState.
func present_echo_offer(offer_ids: Array[String], on_pick: Callable, on_done: Callable) -> void:
	var panel := EchoOfferPanel.new()
	$HUD.add_child(panel)
	panel.present(offer_ids, func(id: String) -> void:
		on_pick.call(id)
		var defs := EchoCore.defs()
		if defs.has(id):
			EchoCore.apply_to_player(_player, defs[id])
		_hud.refresh_echoes()  # the new pick joins the shelf immediately
		on_done.call())


# --- HUD -----------------------------------------------------------------------
# The run HUD (RunHud) polls the player for ability cooldowns itself each frame; the
# room only pushes the state it owns (HP, chip, wave, hint, boss) through its setters.

func _on_player_health_changed(hp: int, max_hp: int) -> void:
	if _hud != null:
		_hud.set_hp(hp, max_hp)
	if hp < _last_hp:
		_rig.shake(shake_on_hit)
		_damage_taken = true  # a hit this room — the Hades gate closes until the room clears
	_last_hp = hp


## The Hades quit-gate (design 2026-07-07): the ESC menu may forfeit / Save & Quit only when
## leaving is "clean" — the room is fully cleared, OR the player has not taken a hit here yet
## (mid-fight but untouched still counts). Reprieve/auto-clear rooms are trivially allowed
## (_cleared is set the instant they open). game.gd routes the menu's gate check here.
func can_menu_quit() -> bool:
	return _cleared or not _damage_taken


## The Recovery attunement's heal-on-clear pct configured for this room (0.0 when un-owned).
## For the smoke to drive one recovery heal deterministically via apply_missing_heal.
func recovery_pct() -> float:
	return _recovery_pct
