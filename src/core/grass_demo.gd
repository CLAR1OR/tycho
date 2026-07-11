extends Node3D
## Judging fixture for the grass shader (the gate-scene pattern): a toon-shaded ground
## plane, one GrassPatch, and a capsule dummy wandering a lissajous path through it so
## the walk-through displacement reads without wiring the real player. Run this scene
## directly (F6 / "Run Current Scene"). Everything is placeholder — judge the motion,
## dial the colours (design/feel-tuning.md § Style unification).

const DUMMY_SPEED := 0.5      # style: human-tuned, do not optimize — wander speed
const DUMMY_RANGE := 4.5      # style: human-tuned, do not optimize — wander radius (m)

var _time: float = 0.0
var _dummy: MeshInstance3D = null


func _ready() -> void:
	# Ground — through the unification layer (TOWN_RAMP), like the real town.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 24.0)
	ground.mesh = plane
	ground.set_surface_override_material(0,
		StyleMaterials.toon_material(Color(0.3, 0.32, 0.24), StyleCore.TOWN_RAMP, false))
	add_child(ground)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 11.0, 8.0)
	cam.rotation_degrees = Vector3(-55.0, 0.0, 0.0)  # ~the game's top-down angle
	add_child(cam)

	_dummy = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	_dummy.mesh = capsule
	_dummy.position = Vector3(0.0, 0.8, 0.0)
	_dummy.set_surface_override_material(0,
		StyleMaterials.toon_material(Color(0.85, 0.85, 0.9), StyleCore.NEUTRAL_RAMP, true))
	add_child(_dummy)

	var grass := GrassPatch.new()
	grass.follow_target = _dummy
	add_child(grass)


func _physics_process(delta: float) -> void:
	_time += delta * DUMMY_SPEED
	# Lissajous wander — covers the patch without ever looping the same line.
	_dummy.position = Vector3(
		sin(_time * 1.3) * DUMMY_RANGE, 0.8, sin(_time * 0.9 + 1.7) * DUMMY_RANGE)
