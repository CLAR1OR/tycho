extends Area3D
class_name SnareField
## The Snare etching's ground field (design/etchings.md Q — Fields). A viscosity zone:
## enemies inside have their movement heavily slowed (EnemyDummy.slow_factor), restored
## the instant they leave or the field expires — the slow NEVER persists past the field.
## Squishies (stagger_time > 0) present at cast get a brief stagger; armored never do.
## Placeholder primitives; frees itself after `duration`. Spawned by player._cast_snare.

var slow_factor: float = 0.3
var duration: float = 4.0

var _t: float = 0.0
var _affected: Array = []  # enemies we've slowed (so we can restore exactly them)
var _stagger_on_cast: float = 0.0  # squishy root applied to bodies caught in the cast window


## Configure + build the field. `radius` metres, `stagger_on_cast` staggers squishies
## already inside. Call after adding to the tree and setting global_position.
func setup(radius: float, p_slow: float, p_duration: float, stagger_on_cast: float) -> void:
	slow_factor = p_slow
	duration = p_duration
	collision_layer = 0
	collision_mask = 2  # enemies live on physics layer 2 (enemy_dummy.tscn)
	monitoring = true
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 4.0
	shape.shape = cyl
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.1
	mesh.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.8, 1.0)
	mat.albedo_color = Color(0.5, 0.8, 1.0, 0.3)
	mesh.material_override = mat
	mesh.position = Vector3(0, -0.9, 0)  # sit on the floor (field is centred at cast height)
	add_child(mesh)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# The on-cast squishy root: Area3D only reports overlaps from the NEXT physics step,
	# so get_overlapping_bodies() is empty here — instead _slow() applies the stagger to
	# any body caught during the brief cast window (design: "squishies rooted on cast").
	_stagger_on_cast = stagger_on_cast


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		for e in _affected:
			if is_instance_valid(e):
				e.set("slow_factor", 1.0)
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	_slow(body)


func _on_body_exited(body: Node3D) -> void:
	if body in _affected:
		_affected.erase(body)
		if is_instance_valid(body):
			body.set("slow_factor", 1.0)


func _slow(body: Node3D) -> void:
	if body is EnemyDummy and body not in _affected:
		_affected.append(body)
		body.set("slow_factor", slow_factor)
		# Bodies inside during the cast window take the on-cast root (squishies only —
		# EnemyDummy.stagger() no-ops on armored). Later arrivals are only slowed.
		if _t <= 0.15 and _stagger_on_cast > 0.0 and body.has_method("stagger"):
			body.call("stagger", _stagger_on_cast)
