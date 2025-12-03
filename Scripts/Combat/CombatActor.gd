extends Node3D
class_name CombatActor

@export var animation_player: AnimationPlayer
@export var fallback_animation: StringName = "attack"

func play_hit_feedback() -> void:
	var t := transform
	t.basis = t.basis.scaled(Vector3(1.1, 1.1, 1.1))
	transform = t

func play_death_feedback() -> void:
	visible = false

func play_skill(animation_name: StringName) -> void:
	if animation_player == null:
		return

	var anim_to_play := animation_name
	if anim_to_play == "" and fallback_animation != "":
		anim_to_play = fallback_animation

	if anim_to_play != "":
		animation_player.play(anim_to_play)

func get_skill_anim_length(animation_name: StringName) -> float:
	if animation_player == null:
		return 0.0

	var anim_name := animation_name
	if anim_name == "" and fallback_animation != "":
		anim_name = fallback_animation

	if anim_name == "":
		return 0.0

	if not animation_player.has_animation(anim_name):
		return 0.0

	var anim := animation_player.get_animation(anim_name)
	if anim == null:
		return 0.0

	return anim.length
