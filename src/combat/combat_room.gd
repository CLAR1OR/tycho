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
## Boss rooms spawn the placeholder boss + escorts and pay the boss bounty.
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
@export var gold_per_enemy_min: int = 1
@export var gold_per_enemy_max: int = 3
@export var ore_drop_chance: float = 0.12  # Resonance Ore per kill (weapons sink, PRD §7.10)
@export var boss_gold: int = 25
@export var boss_shards: int = 1         # Knowledge Shards per stage boss (PRD §7.10)
@export var boss_ore: int = 2            # guaranteed Resonance Ore per boss

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

var _enemies: Array[EnemyDummy] = []
# Sequential waves (design 2026-07-06): a combat room runs 2-3 waves; the room only
# CLEARS after the last wave falls. Empty for boss/reprieve rooms (they don't wave).
var _waves: Array = []          # list of Array[String] WaveCore type-ids
var _wave_index: int = 0
var _cleared: bool = false
var _door_chosen: bool = false  # first door walked wins — no backtracking
var _last_hp: int = Player.MAX_HEALTH
# Hades quit-gate (design 2026-07-07): true once the player has taken a hit IN THIS ROOM.
# Never reset within the room — the ESC menu may forfeit / quit only when the room is
# cleared OR the player is still untouched (can_menu_quit).
var _damage_taken: bool = false
var _hud: RunHud  # the in-run HUD (design/ui-hud.md) — chip / HP / echoes / abilities / boss

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _portal: Area3D = $ExitPortal


func setup(p_floor: int, p_room: int, p_rooms_this_floor: int, p_kind: String,
		p_incoming: Dictionary = {}) -> void:
	floor_num = p_floor
	room_index = p_room
	rooms_this_floor = p_rooms_this_floor
	kind = p_kind
	incoming_door = p_incoming.duplicate()
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
		# Boss rooms are a single staged fight — no waves in this chunk.
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


func _wave_spawn_pos(i: int, count: int) -> Vector3:
	# Scatter around the room centre (like feel_room), away from the south spawn.
	var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
	var radius := spawn_radius + randf_range(-spawn_jitter, spawn_jitter)
	return Vector3(cos(angle) * radius, 1.0, sin(angle) * radius - 4.0)


func _on_enemy_died(enemy: EnemyDummy) -> void:
	Ledger.add("gold", float(randi_range(gold_per_enemy_min, gold_per_enemy_max)), "run-drop")
	if randf() < ore_drop_chance:
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
