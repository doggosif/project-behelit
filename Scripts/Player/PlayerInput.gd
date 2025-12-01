class_name PlayerInput
extends Node

var move_axis: Vector2 = Vector2.ZERO
var mouse_delta: Vector2 = Vector2.ZERO
var snap_left_pressed := false
var snap_right_pressed:= false
var interact_pressed := false

func _process(_delta: float) -> void:
	# wasd movement
	move_axis = Input.get_vector(
		"move_left",
		"move_right",
		"move_back",
        "move_forward"
	)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		mouse_delta += m.relative

	if event.is_action_pressed("camera_rotate_left"):
		snap_left_pressed = true
	if event.is_action_pressed("camera_rotate_right"):
		snap_right_pressed = true
	
	if Input.is_action_just_pressed("interact"):
		interact_pressed = true

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("ui_accept"):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
