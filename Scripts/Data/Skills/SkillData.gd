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

# Name of the animation to play on the CombatActor
@export var animation_name: StringName = ""

# NEW: optional status effect this skill applies when it resolves
@export var status_to_apply: StatusEffectData
@export var status_stacks: int = 1
