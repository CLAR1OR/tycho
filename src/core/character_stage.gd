extends Node3D
class_name CharacterStage
## Phase 0 gate 3 — the ASSET-PIPELINE gate.
##
## Validates the 2.5D pipeline assumption end-to-end:
##   Tripo model -> rig -> Quaternius/UAL animation retarget -> animated in a
##   Godot scene UNDER THE FIXED CAMERA (the same camera_rig.tscn the game uses).
##
## How to use (see assets/README.md for the full pipeline):
##   1. Produce a rigged, animated character and export a .glb.
##   2. Drop it at res://assets/models/gate_character.glb (the default drop-point),
##      OR assign any PackedScene to `model_scene` in the inspector.
##   3. Run this scene. It finds the AnimationPlayer, lists the clips, and plays
##      them under the fixed camera. A/D cycle clips; Space toggles the turntable.
##
## If no model is found it spawns a procedurally-bobbing placeholder so the scene
## always runs — failure to find a model is NOT a project no-go (CLAUDE.md: the
## fallback is stock Quaternius models or learning Blender).

@export var model_scene: PackedScene = null
const MODEL_PATH := "res://assets/models/gate_character.glb"  # convention drop-point

# FEEL: turntable speed (deg/s) — purely for inspecting the model from all sides.
const TURNTABLE_SPEED := 35.0
const PLACEHOLDER_BOB_HEIGHT := 0.25
const PLACEHOLDER_BOB_SPEED := 3.0

@onready var _rig: CameraRig = $CameraRig
@onready var _info: Label = $HUD/Info
@onready var _holder: Node3D = $ModelHolder

var _anim_player: AnimationPlayer = null
var _anim_names: PackedStringArray = []
var _anim_idx: int = 0
var _turntable: bool = true
var _is_placeholder: bool = false
var _bob_t: float = 0.0


func _ready() -> void:
	_rig.set_target(_holder)
	var scene := _resolve_model_scene()
	if scene != null:
		var inst := scene.instantiate()
		_holder.add_child(inst)
		# Style layer (design/asset-pipeline.md §C): the gate judges every model UNDER
		# the unification layer — toon on the NEUTRAL character ramp + outline — because
		# that is how it will render in game (the whole point of the layer). Baked albedo
		# textures carry through; translucent/unshaded materials are skipped.
		StyleMaterials.apply_to_tree(inst, StyleCore.NEUTRAL_RAMP, true)
		_anim_player = _find_anim_player(inst)
		if _anim_player != null:
			_collect_animations()
			_play_current()
	else:
		_spawn_placeholder()
	_update_info()


func _resolve_model_scene() -> PackedScene:
	if model_scene != null:
		return model_scene
	if ResourceLoader.exists(MODEL_PATH):
		return load(MODEL_PATH) as PackedScene
	return null


func _process(delta: float) -> void:
	if _turntable:
		_holder.rotate_y(deg_to_rad(TURNTABLE_SPEED) * delta)
	if _is_placeholder:
		_bob_t += delta * PLACEHOLDER_BOB_SPEED
		_holder.position.y = absf(sin(_bob_t)) * PLACEHOLDER_BOB_HEIGHT


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		_turntable = not _turntable
		_update_info()
	elif event.is_action_pressed("move_right"):
		_cycle_animation(1)
	elif event.is_action_pressed("move_left"):
		_cycle_animation(-1)


# --- Animation --------------------------------------------------------------

func _collect_animations() -> void:
	_anim_names.clear()
	for name in _anim_player.get_animation_list():
		# Skip the implicit RESET clip Godot adds.
		if name == "RESET":
			continue
		_anim_names.append(name)
		# Force clips to loop so the gate shows continuous motion.
		var clip := _anim_player.get_animation(name)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR


func _play_current() -> void:
	if _anim_names.is_empty():
		return
	_anim_player.play(_anim_names[_anim_idx])


func _cycle_animation(dir: int) -> void:
	if _anim_names.is_empty():
		return
	_anim_idx = wrapi(_anim_idx + dir, 0, _anim_names.size())
	_play_current()
	_update_info()


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for child in n.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null


# --- Placeholder ------------------------------------------------------------

func _spawn_placeholder() -> void:
	_is_placeholder = true
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	# Same unification treatment as a real model (toon, NEUTRAL ramp, outlined), so the
	# placeholder previews the character look too.
	body.material_override = StyleMaterials.toon_material(
		Color(0.5, 0.55, 0.7), StyleCore.NEUTRAL_RAMP, true)
	_holder.add_child(body)


# --- HUD --------------------------------------------------------------------

func _update_info() -> void:
	var lines: Array[String] = []
	if _is_placeholder:
		lines.append("[PLACEHOLDER] No model at %s — drop a rigged .glb there." % MODEL_PATH)
		lines.append("Gate is not yet validated; see assets/README.md for the pipeline.")
	else:
		lines.append("Model loaded.")
		if _anim_names.is_empty():
			lines.append("WARNING: no AnimationPlayer/clips found — retarget step incomplete.")
		else:
			lines.append("Clip %d/%d: %s" % [_anim_idx + 1, _anim_names.size(), _anim_names[_anim_idx]])
	lines.append("A/D cycle clips - Space toggle turntable (%s)" % ("on" if _turntable else "off"))
	_info.text = "\n".join(lines)
