extends Node3D
class_name CameraRig
## The single reusable fixed-camera rig (the 2.5D decision — godot-conventions.md).
## NOTHING else in the project may assume camera angles; everyone goes through this.
## The rig node lerp-follows a target on the ground plane; the Camera3D child holds
## the fixed top-down-with-tilt offset and pitch.

# FEEL: human-tuned, do not optimize — camera framing is part of combat feel.
const FOLLOW_LERP := 9.0              # FEEL: higher = snappier follow, lower = floatier
const CAM_OFFSET := Vector3(0, 15, 9) # FEEL: height + pull-back of the fixed camera
const CAM_PITCH := -58.0              # FEEL: downward tilt in degrees (the 2.5D angle)

var _target: Node3D = null


func _ready() -> void:
	var cam: Camera3D = $Camera3D
	cam.position = CAM_OFFSET
	cam.rotation_degrees = Vector3(CAM_PITCH, 0.0, 0.0)


func set_target(target: Node3D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	# Frame-rate independent exponential smoothing toward the target's ground position.
	var t: float = 1.0 - exp(-FOLLOW_LERP * delta)
	global_position = global_position.lerp(_target.global_position, t)
