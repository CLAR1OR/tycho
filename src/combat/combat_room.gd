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
## open_exit() and the portal lights up → player steps in → `exit_entered`.
## Boss rooms spawn the placeholder boss + escorts and pay the boss bounty.

const ENEMY_BRUTE := preload("res://scenes/combat/enemy_dummy.tscn")
const ENEMY_SKIRMISHER := preload("res://scenes/combat/enemy_skirmisher.tscn")
const ENEMY_ARCHER := preload("res://scenes/combat/enemy_archer.tscn")
const ENEMY_BOSS := preload("res://scenes/combat/enemy_boss.tscn")

## Placeholder until real per-floor bosses land (PRD §7.7 — bosses are human-gated).
const BOSS_ID := "boss-placeholder"

const PLAYER_SPAWN := Vector3(0, 0, 18)  # south edge; the wave scatters around centre

# FEEL knobs — same names as feel_room.gd, so the F1 tuning panel works in-run too.
@export var enemy_count: int = 3         # FEEL: base enemies in a combat room (scaled by floor+room)
@export var respawn_delay: float = 0.9   # FEEL: beat between the last kill and the exit opening (s)
@export var shake_on_hit: float = 0.35   # FEEL: camera kick (m) when the player takes a hit
@export var spawn_radius: float = 16.0   # FEEL: how far out around the room the wave scatters (m)
@export var spawn_jitter: float = 3.0    # FEEL: random wobble on each spawn point (m)

# Drop economy — placeholder numbers (economy tuning is an OPEN question, PRD §13).
@export var gold_per_enemy_min: int = 1
@export var gold_per_enemy_max: int = 3
@export var boss_gold: int = 25
@export var boss_shards: int = 1         # Knowledge Shards per stage boss (PRD §7.10)

signal cleared        # the wave is down; the orchestrator decides what happens next
signal exit_entered   # the player stepped into the open exit portal
signal player_died    # HP hit 0 in this room

# Where in the run this room sits — set via setup() before entering the tree.
var floor_num: int = 1
var room_index: int = 1
var rooms_this_floor: int = 1
var kind: String = RunFlow.KIND_COMBAT

var _enemies: Array[EnemyDummy] = []
var _cleared: bool = false
var _last_hp: int = Player.MAX_HEALTH

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _portal: Area3D = $ExitPortal
@onready var _room_label: Label = $HUD/RoomInfo
@onready var _hp_label: Label = $HUD/HP
@onready var _hint_label: Label = $HUD/Hint


func setup(p_floor: int, p_room: int, p_rooms_this_floor: int, p_kind: String) -> void:
	floor_num = p_floor
	room_index = p_room
	rooms_this_floor = p_rooms_this_floor
	kind = p_kind


func _ready() -> void:
	_rig.set_target(_player)
	_player.position = PLAYER_SPAWN
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(func() -> void: player_died.emit())
	_portal.visible = false
	_portal.monitoring = false
	_portal.body_entered.connect(_on_portal_body_entered)
	if kind == RunFlow.KIND_BOSS:
		_room_label.text = "Floor %d — BOSS" % floor_num
	else:
		_room_label.text = "Floor %d — Room %d/%d" % [floor_num, room_index, rooms_this_floor]
	_hint_label.text = "Clear the room - F1 tuning"
	# Carry the run's build + wounds onto this room's FRESH player instance:
	# echoes re-apply from RunState, HP carries over (rooms must not free-heal).
	EchoCore.apply_all_to_player(_player, RunState.echoes)
	if RunState.player_health > 0:
		_player.restore_health(RunState.player_health)
	_spawn_wave()
	# Same live feel-tuning panel as the sandbox (F1) — dials apply to THIS room's
	# instances plus the shared static knobs (hitstop, crowd rules).
	var panel := TuningPanel.new()
	$HUD.add_child(panel)
	panel.setup(_player, _rig, self)


# --- Wave ---------------------------------------------------------------------

func _spawn_wave() -> void:
	if kind == RunFlow.KIND_BOSS:
		_spawn_enemy(ENEMY_BOSS, Vector3(0, 1.0, -14))
		_spawn_enemy(ENEMY_SKIRMISHER, Vector3(-8, 1.0, -10))
		_spawn_enemy(ENEMY_SKIRMISHER, Vector3(8, 1.0, -10))
		return
	# Simple pressure curve: deeper floors and later rooms add a body each.
	var count := enemy_count + (room_index - 1) + (floor_num - 1)
	for i in count:
		_spawn_enemy(_scene_for(i), _wave_spawn_pos(i, count))


func _spawn_enemy(scene: PackedScene, pos: Vector3) -> void:
	var enemy: EnemyDummy = scene.instantiate()
	enemy.position = pos
	enemy.target = _player
	add_child(enemy)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	_enemies.append(enemy)


func _scene_for(i: int) -> PackedScene:
	match i % 3:
		1:
			return ENEMY_SKIRMISHER
		2:
			return ENEMY_ARCHER
		_:
			return ENEMY_BRUTE


func _wave_spawn_pos(i: int, count: int) -> Vector3:
	# Scatter around the room centre (like feel_room), away from the south spawn.
	var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
	var radius := spawn_radius + randf_range(-spawn_jitter, spawn_jitter)
	return Vector3(cos(angle) * radius, 1.0, sin(angle) * radius - 4.0)


func _on_enemy_died(enemy: EnemyDummy) -> void:
	Ledger.add("gold", float(randi_range(gold_per_enemy_min, gold_per_enemy_max)), "run-drop")
	_enemies.erase(enemy)
	if _enemies.is_empty() and not _cleared:
		_cleared = true
		if kind == RunFlow.KIND_BOSS:
			Ledger.add("gold", float(boss_gold), "boss-drop")
			Ledger.add("knowledge-shards", float(boss_shards), "boss-drop")
		cleared.emit()


# --- Exit ----------------------------------------------------------------------

## Called by the orchestrator when the run continues past this room.
func open_exit() -> void:
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_portal.visible = true
	_portal.monitoring = true
	_hint_label.text = "Exit open — step into the light"


func _on_portal_body_entered(body: Node3D) -> void:
	if body is Player:
		RunState.player_health = _player.health  # wounds carry into the next room
		exit_entered.emit()


# --- Echo offer -----------------------------------------------------------------

## Called by the orchestrator after a combat-room clear: pause, offer 3 echoes,
## apply the pick to this room's player, then open the exit. `on_pick` is the
## orchestrator's bookkeeping callback (records the pick on RunState).
func present_echo_offer(offer_ids: Array[String], on_pick: Callable) -> void:
	var panel := EchoOfferPanel.new()
	$HUD.add_child(panel)
	panel.present(offer_ids, func(id: String) -> void:
		on_pick.call(id)
		var defs := EchoCore.defs()
		if defs.has(id):
			EchoCore.apply_to_player(_player, defs[id])
		open_exit())


# --- HUD -----------------------------------------------------------------------

func _on_player_health_changed(hp: int, max_hp: int) -> void:
	_hp_label.text = "HP: %d / %d" % [hp, max_hp]
	if hp < _last_hp:
		_rig.shake(shake_on_hit)
	_last_hp = hp
