extends Node3D
class_name CameraRig
## The single reusable fixed-camera rig (the 2.5D decision — godot-conventions.md).
## NOTHING else in the project may assume camera angles; everyone goes through this.
## The rig node lerp-follows a target on the ground plane; the Camera3D child holds
## the fixed top-down-with-tilt offset and pitch.

# FEEL: human-tuned, do not optimize — camera framing is part of combat feel.
# @export so the Inspector and the F1 tuning panel can dial them live.
@export var follow_lerp: float = 9.0                # FEEL: higher = snappier follow, lower = floatier
@export var cam_offset := Vector3(0, 15, 9)         # FEEL: height + pull-back of the fixed camera
@export var cam_pitch: float = -58.0                # FEEL: downward tilt in degrees (the 2.5D angle)
@export var shake_decay: float = 6.0                # FEEL: how fast a shake settles (higher = snappier)

var _target: Node3D = null
var _cam: Camera3D = null
var _shake_strength: float = 0.0


func _ready() -> void:
	_cam = $Camera3D
	_cam.position = cam_offset


func set_target(target: Node3D) -> void:
	_target = target
	if _target != null:
		global_position = _target.global_position


## Kick the camera. `strength` is in metres of peak offset. FEEL: callers pass small
## values (~0.2–0.4 for a hit); the rig decays it to zero.
func shake(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)


func _physics_process(delta: float) -> void:
	# Re-applied every frame (not just _ready) so live tuning of the framing works.
	_cam.rotation_degrees = Vector3(cam_pitch, 0.0, 0.0)

	if _target != null:
		# Frame-rate independent exponential smoothing toward the target's ground position.
		var t: float = 1.0 - exp(-follow_lerp * delta)
		global_position = global_position.lerp(_target.global_position, t)

	# Screen shake: random in-plane jitter on the camera, decaying to zero.
	if _shake_strength > 0.001:
		var offset := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_strength
		_cam.position = cam_offset + offset
		_shake_strength = lerpf(_shake_strength, 0.0, 1.0 - exp(-shake_decay * delta))
	else:
		_shake_strength = 0.0
		_cam.position = cam_offset
