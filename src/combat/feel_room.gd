extends Node3D
## Phase 0 combat-feel GATE sandbox controller.
##
## This is the go/no-go for the whole project (CLAUDE.md → Build order, Phase 0).
## Pass bar: "after the 20th clear of the same room, you still want one more."
## It does NOT need to feel like Hades — its own feel is fine.
##
## Throwaway by design: one room, one Tycho, one enemy, dash + light attack,
## placeholder primitives. Tune feel in player.gd / enemy_dummy.gd / camera_rig.gd.
## A clear = killing the enemy; it respawns so you can chase the 20th-clear bar.

const ENEMY_SCENE := preload("res://scenes/combat/enemy_dummy.tscn")
const RESPAWN_DELAY := 0.8     # FEEL: beat between kill and next spawn (s)
const SPAWN_POS := Vector3(0.0, 1.0, -9.0)

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _clears_label: Label = $HUD/Clears
@onready var _hp_label: Label = $HUD/HP
@onready var _hint_label: Label = $HUD/Hint

var _clears: int = 0
var _enemy: EnemyDummy = null


func _ready() -> void:
	_rig.set_target(_player)
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_clears_label.text = "Clears: 0"
	_hint_label.text = "WASD move · mouse aim · LMB attack · Space dash · Esc/Enter reset"
	_spawn_enemy()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset()


func _spawn_enemy() -> void:
	_enemy = ENEMY_SCENE.instantiate()
	_enemy.position = SPAWN_POS
	_enemy.target = _player
	add_child(_enemy)
	_enemy.died.connect(_on_enemy_died)


func _on_enemy_died() -> void:
	_clears += 1
	_clears_label.text = "Clears: %d" % _clears
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	if is_inside_tree():
		_spawn_enemy()


func _on_player_health_changed(hp: int, max_hp: int) -> void:
	_hp_label.text = "HP: %d / %d" % [hp, max_hp]


func _on_player_died() -> void:
	_reset()


func _reset() -> void:
	if _enemy != null and is_instance_valid(_enemy):
		_enemy.queue_free()
	_player.revive()
	_spawn_enemy()
