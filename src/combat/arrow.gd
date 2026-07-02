extends Area3D
class_name Arrow
## A simple ranged projectile fired by the Archer. Flies straight, damages the player
## on contact, and dies on any hit or after its lifetime. Friendly fire is OFF — it
## doesn't collide with the enemy layer (mask = player + walls only). Spawned by
## enemy_archer.gd. Numbers marked `# FEEL:` are human-tuning territory.

const SPEED := 17.0      # FEEL: archer arrow travel speed (m/s)
const LIFETIME := 3.0    # seconds before it despawns if it hits nothing

var _vel: Vector3 = Vector3.ZERO
var _damage: int = 10
var _hit_color: Color = Color(1.0, 0.5, 0.5)
var _t: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Aim + arm the arrow. Call after adding it to the tree and setting global_position.
## Defaults keep the archer's behaviour; the player's bow passes its own speed,
## a white damage-number colour, and sets collision_mask = enemies + walls itself.
func setup(dir: Vector3, damage: int, speed: float = SPEED, hit_color: Color = Color(1.0, 0.5, 0.5)) -> void:
	_damage = damage
	_hit_color = hit_color
	var d := dir
	if d.length() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	_vel = d * speed
	look_at(global_position + d, Vector3.UP)


func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_t += delta
	if _t >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(_damage, global_position)
		CombatFX.damage_number(get_parent(), body.global_position + Vector3.UP * 1.6, _damage, _hit_color)
	queue_free()  # also dies on hitting a wall / cover (which has no take_damage)
