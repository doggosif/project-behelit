extends Node3D

signal combat_finished(result: CombatResult)

@onready var sim: CombatSim = $Sim
@onready var battlefield_root: Node3D = $Battlefield
@onready var player_root: Node3D = $Battlefield/PlayerRoot
@onready var player_spawn: Node3D = $Battlefield/PlayerSpawn
@onready var enemies_root: Node3D = $Battlefield/EnemiesRoot
@onready var combat_ui: CombatUI = $UI/Panel

var _player_actor: Node3D = null
var _enemy_actors: Array[Node3D] = []
var _last_enemies_hp: Array[int] = []
var _last_player_hp: int = -1

var _is_player_casting: bool = false
var _pending_skill_index: int = -1
var _pending_target_index: int = -1

func setup(encounter: EncounterData) -> void:
	# Reset cached HP state
	_last_enemies_hp.clear()
	_last_player_hp = -1
	
	# 1) Battlefield visuals
	if encounter.battlefield_scene:
		var bf := encounter.battlefield_scene.instantiate()
		battlefield_root.add_child(bf)

	# 2) Connect to Sim signals (once)
	if not sim.hp_changed.is_connected(_on_hp_changed):
		sim.hp_changed.connect(_on_hp_changed)

	if not sim.combat_finished.is_connected(_on_sim_combat_finished):
		sim.combat_finished.connect(_on_sim_combat_finished)

	# 3) Feed enemies into Sim
	if encounter.enemies.size() > 0:
		sim.setup_enemies(encounter.enemies)

	# 4) Spawn player + enemies visually
	_spawn_player_actor()
	_spawn_enemy_actors(encounter.enemies)

	if combat_ui and not combat_ui.skill_requested.is_connected(_on_skill_requested):
		combat_ui.skill_requested.connect(_on_skill_requested)
	
	if not sim.enemy_action_started.is_connected(_on_enemy_action_started):
		sim.enemy_action_started.connect(_on_enemy_action_started)


func _spawn_player_actor() -> void:
	# Clear old
	if _player_actor and is_instance_valid(_player_actor):
		_player_actor.queue_free()
	_player_actor = null

	if sim.player_data == null:
		push_error("CombatSim has no player_data assigned.")
		return

	var scene: PackedScene = sim.player_data.actor_scene
	if scene == null:
		push_error("Player CombatantData has no actor_scene assigned.")
		return

	var actor := scene.instantiate() as Node3D
	_player_actor = actor
	player_root.add_child(actor)

	if player_spawn:
		actor.global_transform = player_spawn.global_transform


func _spawn_enemy_actors(enemies: Array[CombatantData]) -> void:
	# Clear old
	for a in _enemy_actors:
		if is_instance_valid(a):
			a.queue_free()
	_enemy_actors.clear()

	for i in range(enemies.size()):
		var data := enemies[i]
		if data.actor_scene == null:
			continue

		var actor := data.actor_scene.instantiate() as Node3D
		enemies_root.add_child(actor)
		_enemy_actors.append(actor)

		# Try a marker: EnemySpawn0, EnemySpawn1, ...
		var marker_path := "EnemySpawn%d" % i
		var marker := battlefield_root.get_node_or_null(marker_path)
		if marker and marker is Node3D:
			actor.global_transform = marker.global_transform
		else:
			# fallback: spread along X
			var t := actor.transform
			t.origin = Vector3(2.0 * i, 0.0, 0.0)
			actor.transform = t


func _on_hp_changed(player_hp: int, enemies_hp: Array[int]) -> void:
	# Player HP feedback
	if _last_player_hp == -1:
		_last_player_hp = player_hp
	else:
		if player_hp < _last_player_hp:
			_on_player_hit()
		if player_hp <= 0 and _last_player_hp > 0:
			_on_player_died()
		_last_player_hp = player_hp

	# Enemy HP feedback
	if _last_enemies_hp.is_empty():
		_last_enemies_hp = enemies_hp.duplicate()
		return

	for i in range(min(enemies_hp.size(), _enemy_actors.size())):
		var old_hp := _last_enemies_hp[i]
		var new_hp := enemies_hp[i]

		if new_hp <= 0 and old_hp > 0:
			_on_enemy_died(i)
		elif new_hp < old_hp:
			_on_enemy_hit(i)

	_last_enemies_hp = enemies_hp.duplicate()


func _on_enemy_died(index: int) -> void:
	var ca := _get_enemy_combat_actor(index)
	if ca == null:
		return
	ca.play_death_feedback()


func _on_enemy_hit(index: int) -> void:
	var ca := _get_enemy_combat_actor(index)
	if ca == null:
		return
	ca.play_hit_feedback()

func _on_player_hit() -> void:
	var ca := _get_player_combat_actor()
	if ca == null:
		return
	ca.play_hit_feedback()


func _on_sim_combat_finished(result: CombatResult) -> void:
	combat_finished.emit(result)


func _on_player_died() -> void:
	var ca := _get_player_combat_actor()
	if ca == null:
		# fallback: at least hide the node
		if _player_actor and is_instance_valid(_player_actor):
			_player_actor.visible = false
		return

	ca.play_death_feedback()

func _on_skill_requested(skill_index: int, target_index: int) -> void:
	# Do not allow player skills when it's not their turn
	if sim.current_turn != CombatSim.Turn.PLAYER:
		return

	if _is_player_casting:
		return

	if sim.player_data == null:
		return
	if skill_index < 0 or skill_index >= sim.player_data.skills.size():
		return

	var skill := sim.player_data.skills[skill_index]
	if skill == null:
		return

	# 1) Always start the animation
	_play_player_skill_anim(skill)

	# 2) Figure out how long that animation actually is
	var actor := _get_player_combat_actor()
	var anim_length := 0.0
	if actor and skill is SkillData:
		anim_length = actor.get_skill_anim_length(skill.animation_name)

	if anim_length <= 0.0:
		# No valid anim or length -> resolve instantly
		sim.player_use_skill_on_target(skill_index, target_index)
		return

	# 3) Delay resolution until animation is done
	_is_player_casting = true
	_pending_skill_index = skill_index
	_pending_target_index = target_index

	_start_cast_timer(anim_length)

func _get_player_combat_actor() -> CombatActor:
	if _player_actor == null or not is_instance_valid(_player_actor):
		return null

	var ca := _player_actor as CombatActor
	if ca != null:
		return ca

	for child in _player_actor.get_children():
		if child is CombatActor:
			return child

	return null

func _play_player_skill_anim(skill: SkillData) -> void:
	var actor := _get_player_combat_actor()
	if actor == null:
		return

	var anim_name: StringName = ""
	if skill != null:
		anim_name = skill.animation_name

	actor.play_skill(anim_name)

func _start_cast_timer(delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	await timer.timeout

	if not _is_player_casting:
		return

	_is_player_casting = false

	var skill_index := _pending_skill_index
	var target_index := _pending_target_index

	_pending_skill_index = -1
	_pending_target_index = -1

	# Apply the skill effects after the delay
	sim.player_use_skill_on_target(skill_index, target_index)

func _get_enemy_combat_actor(index: int) -> CombatActor:
	if index < 0 or index >= _enemy_actors.size():
		return null

	var node := _enemy_actors[index]
	if node == null or not is_instance_valid(node):
		return null

	var ca := node as CombatActor
	if ca != null:
		return ca

	# fallback: look for a child CombatActor, if you ever nest it
	for child in node.get_children():
		if child is CombatActor:
			return child

	return null

func _on_enemy_action_started(enemy_index: int, skill: SkillData) -> void:
	var actor := _get_enemy_combat_actor(enemy_index)
	var anim_len := 0.0
	var anim_name: StringName = ""

	if skill != null:
		anim_name = skill.animation_name

	if actor:
		actor.play_skill(anim_name)
		anim_len = actor.get_skill_anim_length(anim_name)

	if anim_len <= 0.0:
		# No valid anim or zero length -> resolve immediately
		sim.resolve_current_enemy_action()
		return

	# Delay resolution until the enemy animation finishes
	_resolve_enemy_action_after_delay(anim_len)

func _resolve_enemy_action_after_delay(delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	await timer.timeout
	sim.resolve_current_enemy_action()
