extends Resource
class_name SkillData

enum TargetType {
	SINGLE_ENEMY,
	ALL_ENEMIES,
	SELF
}

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""

# Name of the animation to play on the actor for this skill.
@export var animation_name: StringName = ""
