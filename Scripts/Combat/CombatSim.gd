class_name CombatSim
extends Node

enum Turn {
	PLAYER,
	ENEMY
}

@export var player_data: CombatantData

var enemies_data: Array[CombatantData] = []
var enemies_hp: Array[int] = []

var player_hp: int
var current_turn: Turn = Turn.PLAYER

# Simple status containers for now
var player_status := {
	"defense_factor": 1.0,
}

var enemies_status: Array[Dictionary] = []

signal hp_changed(player_hp: int, enemies_hp: Array[int])
signal turn_changed(current_turn: Turn)
signal combat_finished(result: CombatResult)
signal enemy_action_started(enemy_index: int, skill: SkillData)

var _enemy_turn_running: bool = false
var _enemy_action_enemy_index: int = -1
var _enemy_action_skill_index: int = -1
var _enemy_action_target_index: int = -1

func _ready() -> void:
	if player_data:
		player_hp = player_data.max_hp
	else:
		player_hp = 20

	_emit_hp()
	_emit_turn()


func setup_enemies(enemy_list: Array[CombatantData]) -> void:
	enemies_data = enemy_list.duplicate()
	enemies_hp.clear()
	enemies_status.clear()

	for e in enemies_data:
		enemies_hp.append(e.max_hp)
		enemies_status.append({
			"defense_factor": 1.0,
		})

	_emit_hp()


func _emit_hp() -> void:
	hp_changed.emit(player_hp, enemies_hp)


func _emit_turn() -> void:
	turn_changed.emit(current_turn)


func _emit_result(player_won: bool) -> void:
	var result := CombatResult.new()
	result.player_survived = player_won
	result.player_hp_remaining = max(player_hp, 0)

	if player_won:
		for i in range(enemies_data.size()):
			if enemies_hp[i] <= 0:
				result.enemies_defeated.append(enemies_data[i])

	combat_finished.emit(result)


func player_attack() -> void:
	if current_turn != Turn.PLAYER:
		return

	var target_index := _get_first_alive_enemy_index()
	if target_index == -1:
		_emit_result(true)
		return

	# use player damage, not enemy damage
	if player_data:
		enemies_hp[target_index] -= player_data.attack_power
	else:
		enemies_hp[target_index] -= 3

	_emit_hp()

	if _all_enemies_dead():
		_emit_result(true)
		return

	current_turn = Turn.ENEMY
	_emit_turn()
	enemy_take_turn()


func enemy_take_turn() -> void:
	if current_turn != Turn.ENEMY:
		return

	_enemy_turn_running = true
	_enemy_action_enemy_index = -1
	_enemy_action_skill_index = -1
	_enemy_action_target_index = -1

	_run_next_enemy_action()

func _enemy_use_skill(enemy_index: int, skill: SkillData) -> void:
	if skill is DamageSkillData:
		_enemy_damage_skill(skill as DamageSkillData)
	elif skill is HealSkillData:
		_enemy_heal_skill(enemy_index, skill as HealSkillData)
	elif skill is DefendSkillData:
		_enemy_defend_skill(enemy_index, skill as DefendSkillData)

func _get_first_alive_enemy_index() -> int:
	for i in range(enemies_hp.size()):
		if enemies_hp[i] > 0:
			return i
	return -1


func _all_enemies_dead() -> bool:
	for hp in enemies_hp:
		if hp > 0:
			return false
	return true

func player_attack_target(target_index: int) -> void:
	# default to skill 0
	player_use_skill_on_target(0, target_index)

func player_use_skill_on_target(skill_index: int, target_index: int) -> void:
	if current_turn != Turn.PLAYER:
		return
	if player_data == null:
		return
	if skill_index < 0 or skill_index >= player_data.skills.size():
		return

	var skill := player_data.skills[skill_index]
	if skill == null:
		return

	if skill is DamageSkillData:
		_player_skill_damage(skill as DamageSkillData, target_index)
	elif skill is HealSkillData:
		_player_skill_heal(skill as HealSkillData)
	elif skill is DefendSkillData:
		_player_skill_defend(skill as DefendSkillData)


func _use_skill_single_enemy(skill: SkillData, target_index: int) -> void:
	if target_index < 0 or target_index >= enemies_hp.size():
		return
	if enemies_hp[target_index] <= 0:
		return

	enemies_hp[target_index] -= skill.power
	_after_player_action()


func _use_skill_all_enemies(skill: SkillData) -> void:
	if enemies_hp.is_empty():
		return

	for i in range(enemies_hp.size()):
		if enemies_hp[i] > 0:
			enemies_hp[i] -= skill.power

	_after_player_action()


func _use_skill_self(skill: SkillData) -> void:
	# Simple version: heal / buff HP by power
	player_hp += skill.power
	player_hp = mini(player_hp, player_data.max_hp)

	_after_player_action()

func _after_player_action() -> void:
	_emit_hp()

	if _all_enemies_dead():
		_emit_result(true)
		return

	current_turn = Turn.ENEMY
	_emit_turn()
	enemy_take_turn()

func _apply_damage_to_player(amount: int) -> void:
	var defense_factor: float = player_status.get("defense_factor", 1.0)
	var final_damage := int(round(amount * defense_factor))
	if final_damage < 0:
		final_damage = 0
	player_hp -= final_damage


func _player_skill_damage(skill: DamageSkillData, target_index: int) -> void:
	match skill.target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			if target_index < 0 or target_index >= enemies_hp.size():
				return
			if enemies_hp[target_index] <= 0:
				return
			enemies_hp[target_index] -= skill.power

		SkillData.TargetType.ALL_ENEMIES:
			for i in range(enemies_hp.size()):
				if enemies_hp[i] > 0:
					enemies_hp[i] -= skill.power

		SkillData.TargetType.SELF:
			player_hp -= skill.power  # if you ever want self-harm edgelord skills

	_after_player_action()


func _player_skill_heal(skill: HealSkillData) -> void:
	match skill.target_type:
		SkillData.TargetType.SELF:
			player_hp = min(player_hp + skill.power, player_data.max_hp)

		SkillData.TargetType.ALL_ENEMIES:
			for i in range(enemies_hp.size()):
				var max_hp := enemies_data[i].max_hp
				enemies_hp[i] = min(enemies_hp[i] + skill.power, max_hp)

		SkillData.TargetType.SINGLE_ENEMY:
			# future: heal ally
			pass

	_after_player_action()


func _player_skill_defend(skill: DefendSkillData) -> void:
	if skill.target_type != SkillData.TargetType.SELF:
		return

	player_status["defense_factor"] = skill.defense_factor
	_after_player_action()


func _enemy_damage_skill(skill: DamageSkillData) -> void:
	# For now enemies only target the player
	_apply_damage_to_player(skill.power)

func _enemy_heal_skill(enemy_index: int, skill: HealSkillData) -> void:
	if enemy_index < 0 or enemy_index >= enemies_hp.size():
		return

	var max_hp := enemies_data[enemy_index].max_hp
	enemies_hp[enemy_index] = min(enemies_hp[enemy_index] + skill.power, max_hp)

func _enemy_defend_skill(enemy_index: int, skill: DefendSkillData) -> void:
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index]
	status["defense_factor"] = skill.defense_factor
	enemies_status[enemy_index] = status

func _choose_enemy_action(enemy_index: int) -> Dictionary:
	# For now: always target player with first skill if exists, else basic attack
	var action := {
		"skill_index": -1,   # -1 means "use basic attack"
		"target_index": -1   # -1 = player, later can mean ally index, etc.
	}

	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return action

	var enemy_data := enemies_data[enemy_index]

	if enemy_data.skills.size() > 0:
		action.skill_index = 0

	return action

func _execute_enemy_action(enemy_index: int, action: Dictionary) -> void:
	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return

	var enemy_data := enemies_data[enemy_index]

	var skill_index: int = action.get("skill_index", -1)
	var target_index: int = action.get("target_index", -1)
	# For now, target_index is ignored because enemies only hit the player.

	if skill_index >= 0 and skill_index < enemy_data.skills.size():
		var skill := enemy_data.skills[skill_index]
		if skill != null:
			_enemy_use_skill(enemy_index, skill)
			return

	# Fallback: basic attack
	_apply_damage_to_player(enemy_data.attack_power)

func _run_next_enemy_action() -> void:
	if not _enemy_turn_running:
		return

	# Find next alive enemy after the last one that acted
	var start_index := _enemy_action_enemy_index + 1
	var i := start_index
	var found := false

	while i < enemies_data.size():
		if enemies_hp[i] > 0:
			found = true
			break
		i += 1

	if not found:
		# No more enemies this turn
		_enemy_turn_running = false
		_finish_enemy_turn()
		return

	_enemy_action_enemy_index = i
	var enemy_data := enemies_data[i]
	var action := _choose_enemy_action(i)

	_enemy_action_skill_index = action.get("skill_index", -1)
	_enemy_action_target_index = action.get("target_index", -1)

	var skill: SkillData = null
	if _enemy_action_skill_index >= 0 and _enemy_action_skill_index < enemy_data.skills.size():
		skill = enemy_data.skills[_enemy_action_skill_index]

	# Let the outside world (CombatScene) know this enemy started an action
	enemy_action_started.emit(i, skill)
	# Do NOT apply damage here. CombatScene will call resolve_current_enemy_action() later.

func _finish_enemy_turn() -> void:
	# Defend only lasts one enemy turn
	player_status["defense_factor"] = 1.0

	current_turn = Turn.PLAYER
	_emit_turn()

func resolve_current_enemy_action() -> void:
	if not _enemy_turn_running:
		return
	if _enemy_action_enemy_index < 0 or _enemy_action_enemy_index >= enemies_data.size():
		return

	var enemy_index := _enemy_action_enemy_index

	# If the enemy died before their action resolved, just skip applying
	if enemies_hp[enemy_index] > 0:
		var enemy_data := enemies_data[enemy_index]

		var skill: SkillData = null
		if _enemy_action_skill_index >= 0 and _enemy_action_skill_index < enemy_data.skills.size():
			skill = enemy_data.skills[_enemy_action_skill_index]

		if skill != null:
			_enemy_use_skill(enemy_index, skill)
		else:
			_apply_damage_to_player(enemy_data.attack_power)

	_emit_hp()

	if player_hp <= 0:
		_enemy_turn_running = false
		_emit_result(false)
		return

	# Move on to the next enemy in this turn
	_run_next_enemy_action()
