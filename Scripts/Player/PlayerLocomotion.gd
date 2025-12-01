# /sim/player/PlayerLocomotion.gd
class_name PlayerLocomotion
extends CharacterBody3D

@export var move_speed: float = 6.0
@export var camera_rig: Node3D
@export var input_source: PlayerInput

func _physics_process(delta: float) -> void:
	if input_source == null or camera_rig == null:
		return

	_handle_movement(delta)
	move_and_slide()

func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = input_source.move_axis

	var move_dir: Vector3 = Vector3.ZERO

	if input_dir != Vector2.ZERO:
		var cam_forward: Vector3 = -camera_rig.global_transform.basis.z
		var cam_right: Vector3 = camera_rig.global_transform.basis.x

		cam_forward.y = 0.0
		cam_right.y = 0.0
		cam_forward = cam_forward.normalized()
		cam_right = cam_right.normalized()

		move_dir = (cam_forward * input_dir.y + cam_right * input_dir.x).normalized()

	velocity.x = move_dir.x * move_speed
	velocity.z = move_dir.z * move_speed

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0
