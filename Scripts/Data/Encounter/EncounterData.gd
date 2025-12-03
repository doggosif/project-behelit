extends Resource
class_name EncounterData

@export var enemies: Array[CombatantData] = []
@export var battlefield_scene: PackedScene
@export var can_flee: bool = true
@export var encounter_name: String = ""
