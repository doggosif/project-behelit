extends Node3D

signal combat_finished(result: CombatResult)

@onready var sim := $Sim
@onready var battlefield_root := $Battlefield


func setup(encounter: EncounterData) -> void:
	# 1) Battlefield visuals
	if encounter.battlefield_scene:
		var bf := encounter.battlefield_scene.instantiate()
		battlefield_root.add_child(bf)

	# 2) Enemies into sim (ALL of them now)
	if encounter.enemies.size() > 0:
		sim.setup_enemies(encounter.enemies)

	# 3) Wire result bubbling
	if not sim.combat_finished.is_connected(_on_sim_combat_finished):
		sim.combat_finished.connect(_on_sim_combat_finished)


func _on_sim_combat_finished(result: CombatResult) -> void:
	combat_finished.emit(result)
