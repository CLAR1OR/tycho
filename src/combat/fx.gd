extends RefCounted
class_name CombatFX
## Tiny factory for throwaway combat visual effects. Keeps spawn boilerplate in
## one place so player/enemy code just says CombatFX.slash(...) / .damage_number(...).
## Effects parent into a world Node3D (the room) and free themselves.

const SLASH_SCENE := preload("res://scenes/combat/slash_fx.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/combat/damage_number.tscn")


static func slash(parent: Node, world_pos: Vector3) -> void:
	if parent == null:
		return
	var fx := SLASH_SCENE.instantiate()
	parent.add_child(fx)
	fx.global_position = world_pos


static func damage_number(parent: Node, world_pos: Vector3, amount: int, color: Color) -> void:
	if parent == null:
		return
	var n := DAMAGE_NUMBER_SCENE.instantiate()
	parent.add_child(n)
	n.global_position = world_pos
	if n.has_method("setup"):
		n.setup(amount, color)
