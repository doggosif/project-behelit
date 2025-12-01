extends Resource
class_name CombatResult

@export var player_survived: bool = true
@export var player_hp_remaining: int = 0
@export var enemies_defeated: Array[CombatantData] = []
