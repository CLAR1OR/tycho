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


## A flat ground-circle telegraph that GROWS over `duration` then frees itself — the
## reusable "danger zone" tell (introduced 2026-07-06). Used by the Slammer's AoE
## windup and by wave-spawn markers. Placed on the floor at world_pos; `radius` is the
## final circle radius in metres. Returns the node (callers may free it early).
static func ground_telegraph(parent: Node, world_pos: Vector3, duration: float,
		radius: float, color: Color) -> MeshInstance3D:
	if parent == null:
		return null
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.08
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.albedo_color = Color(color.r, color.g, color.b, 0.3)
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.global_position = Vector3(world_pos.x, 0.06, world_pos.z)
	mesh.scale = Vector3(0.35, 1.0, 0.35)  # opens up over the window so the read grows
	var tween := mesh.create_tween()
	tween.tween_property(mesh, "scale", Vector3(1.0, 1.0, 1.0), duration)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.6, duration)
	tween.tween_callback(mesh.queue_free)
	return mesh


## A thin flat LINE telegraph from `origin` along `dir` for `length` metres, brightening
## over `duration` then freeing itself — the reusable "this lane is dangerous" tell
## (Charger's charge windup). Returns the node (callers may free it early).
static func line_telegraph(parent: Node, origin: Vector3, dir: Vector3, length: float,
		duration: float, color: Color) -> MeshInstance3D:
	if parent == null:
		return null
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.06, length)  # local -Z runs down the lane after look_at
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.albedo_color = Color(color.r, color.g, color.b, 0.15)
	mesh.material_override = mat
	parent.add_child(mesh)
	var center := Vector3(origin.x, 0.07, origin.z) + d * (length * 0.5)
	mesh.global_position = center
	mesh.look_at(center + d, Vector3.UP)
	var tween := mesh.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.7, duration)  # brighter as the charge nears
	tween.tween_callback(mesh.queue_free)
	return mesh


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
