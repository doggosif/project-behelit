extends Resource
class_name CombatantData

@export var display_name: String = "Thing"
@export var max_hp: int = 10
@export var attack_power: int = 3
@export var speed: int = 10

@export var actor_scene: PackedScene
@export var skills: Array[SkillData] = []

# NEW: which AI brain this combatant uses
@export var ai_brain_id: StringName = "default"
