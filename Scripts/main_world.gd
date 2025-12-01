extends Node3D

@export var combat_scene_packed: PackedScene

@onready var player := $Main/Player              # adjust if needed
@onready var world_root := $Main                 # this is what we hide
@onready var overworld_camera := $Main/Player/CameraRig/Camera3D  # your explore camera

var _active_combat: Node = null
var _current_enemy_trigger: Node = null


func _ready() -> void:
	_connect_enemy_triggers()


func _connect_enemy_triggers() -> void:
	# Find all enemies and hook their DetectionArea signals
	for node in get_tree().get_nodes_in_group("enemy"):
		var trigger := node.get_node_or_null("DetectionArea")
		if trigger and trigger.has_signal("combat_requested"):
			trigger.combat_requested.connect(_on_combat_requested.bind(trigger))


func _on_combat_requested(encounter: EncounterData, trigger: Node) -> void:
	if _active_combat != null:
		return  # already in combat, ignore

	_current_enemy_trigger = trigger

	# Disable player movement while in combat
	if player.has_method("set_process"):
		player.set_process(false)
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)

	_start_combat(encounter)


func _start_combat(encounter: EncounterData) -> void:
	print("_start_combat called with encounter = ", encounter)
	if encounter == null:
		push_error("Tried to start combat with a null EncounterData.")
		return

	_active_combat = combat_scene_packed.instantiate()
	add_child(_active_combat)

	# Hide overworld and switch cameras
	world_root.visible = false
	overworld_camera.current = false

	var battle_camera := _active_combat.get_node_or_null("BattleCamera")
	if battle_camera is Camera3D:
		battle_camera.current = true

	# Use the CombatScene API instead of reaching into Sim
	_active_combat.combat_finished.connect(_on_combat_finished)
	_active_combat.setup(encounter)


func _on_combat_finished(result: CombatResult) -> void:
	if _active_combat:
		_active_combat.queue_free()
		_active_combat = null

	if result.player_survived:
		_handle_player_victory(result)
	else:
		_handle_player_defeat(result)

	if result.player_survived:
		world_root.visible = true
		overworld_camera.current = true

		if player.has_method("set_process"):
			player.set_process(true)
		if player.has_method("set_physics_process"):
			player.set_physics_process(true)

func _handle_player_victory(result: CombatResult) -> void:
	if _current_enemy_trigger:
		var enemy_root := _current_enemy_trigger.get_parent()
		if is_instance_valid(enemy_root):
			enemy_root.queue_free()
	_current_enemy_trigger = null
	# later: use result.enemies_defeated, result.player_hp_remaining, etc.


func _handle_player_defeat(result: CombatResult) -> void:
	var tree := get_tree()
	var current_scene := tree.current_scene
	if current_scene:
		tree.reload_current_scene()
