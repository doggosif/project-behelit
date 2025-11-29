extends Node

@export var locomotion: PlayerLocomotion
@export var anim_tree: AnimationTree
@export var min_move_speed: float = 0.1

var state_machine: AnimationNodeStateMachinePlayback

func _ready() -> void:
	if anim_tree == null:
		push_error("anim_tree is NOT assigned in the inspector.")
		return

	state_machine = anim_tree.get("parameters/StateMachine/playback")  # adjust if needed

	if state_machine == null:
		push_error("AnimationTree has no 'parameters/playback'. Copy the real path from the inspector.")
	else:
		anim_tree.active = true

func _process(_delta: float) -> void:
	if locomotion == null:
		return
	if state_machine == null:
		return

	var vel := locomotion.velocity
	var horiz_speed := Vector3(vel.x, 0.0, vel.z).length()

	if horiz_speed > min_move_speed:
		state_machine.travel("Move")  # use your real state name
	else:
		state_machine.travel("Idle")
