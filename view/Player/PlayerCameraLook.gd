class_name PlayerCameraLook
extends Node3D

@export var input_source: PlayerInput
@export var mouse_sensitivity: float = 0.2

func _process(_delta: float) -> void:
	if input_source == null:
		return

	var delta_mouse := input_source.mouse_delta
	if delta_mouse == Vector2.ZERO:
		return

	# consume it so it doesn't accumulate forever
	input_source.mouse_delta = Vector2.ZERO

	var yaw_deg := -delta_mouse.x * mouse_sensitivity
	rotate_y(deg_to_rad(yaw_deg))
