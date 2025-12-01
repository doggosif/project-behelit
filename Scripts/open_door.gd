extends Node3D

@export var open_angle_degrees: float = 90.0

var is_open: bool = false
var closed_y_rotation: float

func _ready() -> void:
	closed_y_rotation = rotation_degrees.y


func interact(_user) -> void:
	is_open = not is_open

	if is_open:
		rotation_degrees.y = closed_y_rotation + open_angle_degrees
	else:
		rotation_degrees.y = closed_y_rotation
