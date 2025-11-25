# /view/player/PlayerView_ModelRotation.gd
class_name PlayerView_ModelRotation
extends Node

@export var locomotion: PlayerLocomotion
@export var model_root: Node3D
@export var rotate_speed: float = 8.0

func _process(delta: float) -> void:
	if locomotion == null or model_root == null:
		return

	# Use horizontal velocity as movement direction
	var horiz_vel := Vector3(locomotion.velocity.x, 0.0, locomotion.velocity.z)
	if horiz_vel.length() < 0.01:
		return

	var move_dir := horiz_vel.normalized()
	var target_basis := Basis.looking_at(move_dir, Vector3.UP)
	model_root.basis = model_root.basis.slerp(target_basis, delta * rotate_speed)
