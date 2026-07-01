extends RefCounted
class_name CombatFX
## Tiny factory for throwaway combat effects. Keeps spawn boilerplate in
## one place so player/enemy code just says CombatFX.slash(...) / .damage_number(...).
## Effects parent into a world Node3D (the room) and free themselves.
##
## Also owns HITSTOP — the whole-game freeze-frame when a hit lands. The knobs are
## `static var` (not const) so the runtime tuning panel can dial them live.

const SLASH_SCENE := preload("res://scenes/combat/slash_fx.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/combat/damage_number.tscn")
const DEATH_FX_SCENE := preload("res://scenes/combat/death_fx.tscn")

# --- Hitstop (FEEL; static vars so the F1 tuning panel can set them) ---
static var hitstop_scale: float = 0.05     # FEEL: how frozen the freeze is (Engine.time_scale)
static var hitstop_light: float = 0.04     # FEEL: freeze on combo hits 1 & 2 (real seconds)
static var hitstop_finisher: float = 0.10  # FEEL: freeze on the 3rd-hit finisher (real seconds)
static var hitstop_kill: float = 0.13      # FEEL: freeze on a killing blow (real seconds)

static var _hitstop_id: int = 0


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


## Shard burst + a bright pop where an enemy dies, tinted to the variant's colour.
static func death_burst(parent: Node, world_pos: Vector3, color: Color) -> void:
	if parent == null:
		return
	var fx: DeathFX = DEATH_FX_SCENE.instantiate()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx.setup(color)


## A translucent after-image of a mesh (dash trail). Frees itself as it fades.
static func dash_ghost(parent: Node, mesh: Mesh, xform: Transform3D, color: Color) -> void:
	if parent == null or mesh == null:
		return
	var g := GhostFX.new()
	parent.add_child(g)
	g.global_transform = xform
	g.setup(mesh, color)


## Freeze the whole game for `duration` REAL seconds (Engine.time_scale dip).
## Overlapping calls: the latest call owns the restore, so a kill-stop started
## mid-light-stop isn't cut short by the earlier one ending.
static func hitstop(node: Node, duration: float) -> void:
	if node == null or not node.is_inside_tree() or duration <= 0.0:
		return
	_hitstop_id += 1
	var id := _hitstop_id
	Engine.time_scale = hitstop_scale
	# process_always + ignore_time_scale so the timer runs through its own freeze.
	await node.get_tree().create_timer(duration, true, false, true).timeout
	if id == _hitstop_id:
		Engine.time_scale = 1.0
