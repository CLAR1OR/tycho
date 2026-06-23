extends Node3D
## Phase 0 combat-feel GATE sandbox controller.
##
## This is the go/no-go for the whole project (CLAUDE.md → Build order, Phase 0).
## Pass bar: "after the 20th clear of the same room, you still want one more."
## It does NOT need to feel like Hades — its own feel is fine.
##
## Throwaway by design: one room, a few enemies, dash + light attack, placeholder
## primitives. Tune feel in player.gd / enemy_dummy.gd / camera_rig.gd.
## A clear = killing the whole wave; a fresh wave spawns so you can chase the
## 20th-clear bar.

const ENEMY_BRUTE := preload("res://scenes/combat/enemy_dummy.tscn")
const ENEMY_SKIRMISHER := preload("res://scenes/combat/enemy_skirmisher.tscn")
const ENEMY_ARCHER := preload("res://scenes/combat/enemy_archer.tscn")
const ENEMY_COUNT := 4         # FEEL: enemies per wave (sandbox knob — tune freely)
const RESPAWN_DELAY := 1.0     # FEEL: beat between clearing a wave and the next (s)
const SHAKE_ON_HIT := 0.35     # FEEL: camera kick (m) when the player takes a hit
const SPAWN_RADIUS := 18.0     # FEEL: how far out around the room the wave scatters (m)
const SPAWN_JITTER := 3.0      # FEEL: random wobble on each spawn point (m)

@onready var _player: Player = $Player
@onready var _rig: CameraRig = $CameraRig
@onready var _clears_label: Label = $HUD/Clears
@onready var _hp_label: Label = $HUD/HP
@onready var _hint_label: Label = $HUD/Hint

var _clears: int = 0
var _enemies: Array[EnemyDummy] = []
var _last_hp: int = Player.MAX_HEALTH


func _ready() -> void:
	_rig.set_target(_player)
	_player.health_changed.connect(_on_player_health_changed)
	_player.died.connect(_on_player_died)
	_clears_label.text = "Clears: 0"
	_hint_label.text = "WASD move - mouse aim - LMB attack - Space dash - Esc/Enter reset"
	_spawn_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_reset()


func _spawn_wave() -> void:
	for i in ENEMY_COUNT:
		# Mix variants across the wave: Brute / Skirmisher / Archer.
		var enemy: EnemyDummy = _scene_for(i).instantiate()
		enemy.position = _wave_spawn_pos(i)
		enemy.target = _player
		add_child(enemy)
		enemy.died.connect(_on_enemy_died.bind(enemy))
		_enemies.append(enemy)


func _scene_for(i: int) -> PackedScene:
	# Rotate through the three variants so each wave is a mix.
	match i % 3:
		1:
			return ENEMY_SKIRMISHER
		2:
			return ENEMY_ARCHER
		_:
			return ENEMY_BRUTE


func _wave_spawn_pos(i: int) -> Vector3:
	# Scatter the wave around the room so the player has to move in, and some enemies
	# start behind cover (dormant until seen). Evenly spaced angles + a little jitter.
	var angle := TAU * float(i) / float(ENEMY_COUNT) + randf_range(-0.3, 0.3)
	var radius := SPAWN_RADIUS + randf_range(-SPAWN_JITTER, SPAWN_JITTER)
	var x := cos(angle) * radius
	var z := sin(angle) * radius
	return Vector3(x, 1.0, z)


func _on_enemy_died(enemy: EnemyDummy) -> void:
	_enemies.erase(enemy)
	if _enemies.is_empty():
		_clears += 1
		_clears_label.text = "Clears: %d" % _clears
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		# Guard against a player reset having already respawned a wave.
		if is_inside_tree() and _enemies.is_empty():
			_spawn_wave()


func _on_player_health_changed(hp: int, max_hp: int) -> void:
	_hp_label.text = "HP: %d / %d" % [hp, max_hp]
	if hp < _last_hp:
		_rig.shake(SHAKE_ON_HIT)
	_last_hp = hp


func _on_player_died() -> void:
	_reset()


func _reset() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	_player.revive()
	_spawn_wave()
