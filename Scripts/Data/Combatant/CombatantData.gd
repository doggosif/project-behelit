extends Resource
class_name CombatantData

@export var display_name: String = "Thing"
@export var max_hp: int = 10
@export var attack_power: int = 3    # you can keep this for now or deprecate later

@export var actor_scene: PackedScene

# NEW: list of skills this combatant can use
@export var skills: Array[SkillData] = []
