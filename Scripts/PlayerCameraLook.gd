class_name PlayerCameraLook
extends Node3D

@export var input_source: PlayerInput
@export var mouse_sensitivity: float = 0.2

# Master toggle for normal mouse look
@export var enable_camera_rotation: bool = true

# Toggle for Q/E snap turn feature
@export var enable_snap_turn: bool = true
@export var snap_angle_degrees: float = 90.0

# How long the smooth turn should take (seconds)
@export var snap_turn_duration: float = 0.15

# If true, you can still move camera with mouse while it's turning
@export var allow_mouse_during_snap: bool = false

var _is_snap_turning: bool = false
var _snap_start_rot_y: float = 0.0
var _snap_target_rot_y: float = 0.0
var _snap_elapsed: float = 0.0


func _process(delta: float) -> void:
	if input_source == null:
		return

	# 1) Handle starting a snap turn from input
	if enable_snap_turn and not _is_snap_turning:
		if Input.is_action_just_pressed("camera_rotate_left"):
			_start_snap_turn(-snap_angle_degrees)
		elif Input.is_action_just_pressed("camera_rotate_right"):
			_start_snap_turn(snap_angle_degrees)

	# 2) Update snap turn if active
	if _is_snap_turning:
		_update_snap_turn(delta)

	# 3) Handle normal mouse look
	if not enable_camera_rotation:
		return

	if _is_snap_turning and not allow_mouse_during_snap:
		# Ignore mouse while turning, but don't eat the delta
		return

	var delta_mouse := input_source.mouse_delta
	if delta_mouse == Vector2.ZERO:
		return

	# consume it
	input_source.mouse_delta = Vector2.ZERO

	var yaw_deg := -delta_mouse.x * mouse_sensitivity
	rotate_y(deg_to_rad(yaw_deg))


func _start_snap_turn(angle_deg: float) -> void:
	_is_snap_turning = true
	_snap_elapsed = 0.0
	_snap_start_rot_y = rotation.y
	_snap_target_rot_y = _snap_start_rot_y + deg_to_rad(angle_deg)


func _update_snap_turn(delta: float) -> void:
	if snap_turn_duration <= 0.0:
		# Safety: if someone sets duration to 0 in inspector, just snap instantly
		rotation.y = _snap_target_rot_y
		_is_snap_turning = false
		return

	_snap_elapsed += delta
	var t := _snap_elapsed / snap_turn_duration
	if t >= 1.0:
		t = 1.0
		_is_snap_turning = false

	# Smoothly interpolate, handling wrap-around properly
	rotation.y = lerp_angle(_snap_start_rot_y, _snap_target_rot_y, t)
