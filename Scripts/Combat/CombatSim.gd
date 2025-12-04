class_name CombatSim
extends Node

# ───────────────────────────────────────────────────
# Types & Signals
# ───────────────────────────────────────────────────

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
	"effects": []  # Array[Dictionary] of runtime effects
}

var enemies_status: Array[Dictionary] = []


signal hp_changed(player_hp: int, enemies_hp: Array[int])
signal turn_changed(current_turn: Turn)
signal combat_finished(result: CombatResult)
signal enemy_action_started(enemy_index: int, skill: SkillData)

# Enemy turn flow state
var _enemy_action_enemy_index: int = -1
var _enemy_action_skill_index: int = -1
var _enemy_action_target_index: int = -1

var _turn_queue: Array = []
var _turn_queue_index: int = -1
var _current_enemy_index: int = -1


# ───────────────────────────────────────────────────
# Lifecycle / Setup
# ───────────────────────────────────────────────────

func _ready() -> void:
	if player_data:
		player_hp = player_data.max_hp
	else:
		player_hp = 20

	_emit_hp()
	# Turn order will be initialized in setup_enemies()


func setup_enemies(enemy_list: Array[CombatantData]) -> void:
	enemies_data = enemy_list.duplicate()
	enemies_hp.clear()
	enemies_status.clear()

	for e in enemies_data:
		enemies_hp.append(e.max_hp)
		enemies_status.append({
			"defense_factor": 1.0,
			"effects": [],
		})

	_emit_hp()

	_build_turn_queue()
	_start_first_turn()


# ───────────────────────────────────────────────────
# Public API (called from outside)
# ───────────────────────────────────────────────────

func player_attack() -> void:
	if current_turn != Turn.PLAYER:
		return

	var target_index: int = _get_first_alive_enemy_index()
	if target_index == -1:
		_emit_result(true)
		return

	var power: int = 3
	if player_data != null:
		power = player_data.attack_power

	enemies_hp[target_index] -= power
	_after_player_action()


func player_attack_target(target_index: int) -> void:
	# default to skill 0
	player_use_skill_on_target(0, target_index)


func player_use_skill_on_target(skill_index: int, target_index: int) -> void:
	if current_turn != Turn.PLAYER:
		return
	if player_data == null:
		return

	var action := _make_player_action_from_skill(skill_index, target_index)
	_apply_player_action(action)


func resolve_current_enemy_action() -> void:
	if _enemy_action_enemy_index < 0 or _enemy_action_enemy_index >= enemies_data.size():
		return

	var enemy_index: int = _enemy_action_enemy_index

	# If the enemy died before their action resolved, just skip applying
	if enemies_hp[enemy_index] > 0:
		var action: Dictionary = _make_enemy_action_from_choice(
			enemy_index,
			_enemy_action_skill_index,
			_enemy_action_target_index
		)

		_apply_enemy_action(action)
		_emit_hp()

		if player_hp <= 0:
			_emit_result(false)
			return

		if _all_enemies_dead():
			_emit_result(true)
			return

	# Clear current enemy action
	_enemy_action_enemy_index = -1
	_enemy_action_skill_index = -1
	_enemy_action_target_index = -1

	_advance_turn()



# ───────────────────────────────────────────────────
# Turn Flow (internal sequencing)
# ───────────────────────────────────────────────────

func _after_player_action() -> void:
	_emit_hp()

	if player_hp <= 0:
		_emit_result(false)
		return

	if _all_enemies_dead():
		_emit_result(true)
		return

	_advance_turn()
	
func _advance_turn() -> void:
	var num_slots: int = _turn_queue.size()
	if num_slots == 0:
		return

	# Try to find next alive actor, at most num_slots steps
	for step in range(num_slots):
		_turn_queue_index = (_turn_queue_index + 1) % num_slots
		var entry: Dictionary = _turn_queue[_turn_queue_index] as Dictionary
		var side_int: int = int(entry.get("side", Turn.ENEMY))
		var enemy_index: int = int(entry.get("enemy_index", -1))

		if side_int == Turn.PLAYER:
			if player_hp > 0:
				current_turn = Turn.PLAYER
				_current_enemy_index = -1
				_emit_turn()
				_on_side_turn_started(true)

				# Statuses might kill player at start of their turn
				if player_hp <= 0:
					_emit_result(false)
					return
				if _all_enemies_dead():
					_emit_result(true)
					return

				# Player acts via UI now
				return
		else:
			if enemy_index >= 0 and enemy_index < enemies_hp.size() and enemies_hp[enemy_index] > 0:
				current_turn = Turn.ENEMY
				_current_enemy_index = enemy_index
				_emit_turn()
				_on_side_turn_started(false)

				# Statuses might kill enemies before they act
				if _all_enemies_dead():
					_emit_result(true)
					return
				if player_hp <= 0:
					_emit_result(false)
					return

				_start_enemy_turn(enemy_index)
				return

	# If we reach here, no valid actors were found
	if player_hp <= 0:
		_emit_result(false)
	elif _all_enemies_dead():
		_emit_result(true)


func _start_enemy_turn(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies_data.size():
		_advance_turn()
		return
	if enemies_hp[enemy_index] <= 0:
		_advance_turn()
		return

	var enemy_data: CombatantData = enemies_data[enemy_index]
	var action: Dictionary = _choose_enemy_action(enemy_index)

	_enemy_action_enemy_index = enemy_index
	_enemy_action_skill_index = int(action.get("skill_index", -1))
	_enemy_action_target_index = int(action.get("target_index", -1))

	var skill: SkillData = null
	if _enemy_action_skill_index >= 0 and _enemy_action_skill_index < enemy_data.skills.size():
		skill = enemy_data.skills[_enemy_action_skill_index]

	enemy_action_started.emit(enemy_index, skill)


# ───────────────────────────────────────────────────
# Player Actions & Effects
# ───────────────────────────────────────────────────

func _make_player_action_from_skill(skill_index: int, target_index: int) -> Dictionary:
	var action := {
		"source": "player",
		"source_index": -1,
		"skill": null,
		"skill_index": skill_index,
		"target_index": target_index,
	}

	if player_data == null:
		return action
	if skill_index < 0 or skill_index >= player_data.skills.size():
		return action

	var skill := player_data.skills[skill_index]
	action["skill"] = skill

	return action


func _apply_player_action(action: Dictionary) -> void:
	var skill: SkillData = action.get("skill", null)
	var skill_index: int = action.get("skill_index", -1)
	var target_index: int = action.get("target_index", -1)

	if skill == null:
		# Optional: fallback to basic attack if you ever want
		if skill_index == -1:
			var target := _get_first_alive_enemy_index()
			if target != -1 and player_data:
				enemies_hp[target] -= player_data.attack_power
				_after_player_action()
		return

	if skill is DamageSkillData:
		_player_skill_damage(skill as DamageSkillData, target_index)
	elif skill is HealSkillData:
		_player_skill_heal(skill as HealSkillData)
	elif skill is StatusSkillData:
		_player_status_skill(skill as StatusSkillData, target_index)



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
			player_hp -= skill.power  # edgy self-harm skills

	# ── NEW: apply status if defined ───────────────────
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		match skill.target_type:
			SkillData.TargetType.SINGLE_ENEMY:
				if target_index >= 0 and target_index < enemies_hp.size():
					_apply_status_to_enemy(target_index, skill.status_to_apply, stacks)

			SkillData.TargetType.ALL_ENEMIES:
				for i in range(enemies_hp.size()):
					if enemies_hp[i] > 0:
						_apply_status_to_enemy(i, skill.status_to_apply, stacks)

			SkillData.TargetType.SELF:
				_apply_status_to_player(skill.status_to_apply, stacks)

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

	# ── NEW: apply status if defined ───────────────────
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		match skill.target_type:
			SkillData.TargetType.SELF:
				_apply_status_to_player(skill.status_to_apply, stacks)

			SkillData.TargetType.ALL_ENEMIES:
				for i in range(enemies_hp.size()):
					_apply_status_to_enemy(i, skill.status_to_apply, stacks)

			SkillData.TargetType.SINGLE_ENEMY:
				# when you add ally targeting, apply there
				pass

	_after_player_action()


func _player_status_skill(skill: StatusSkillData, target_index: int) -> void:
	if skill == null:
		return

	if skill.status_to_apply == null:
		# Skill is basically “do nothing” if no status assigned
		_after_player_action()
		return

	var stacks: int = max(1, int(skill.status_stacks))

	match skill.target_type:
		SkillData.TargetType.SELF:
			_apply_status_to_player(skill.status_to_apply, stacks)

		SkillData.TargetType.SINGLE_ENEMY:
			if target_index >= 0 and target_index < enemies_hp.size():
				_apply_status_to_enemy(target_index, skill.status_to_apply, stacks)

		SkillData.TargetType.ALL_ENEMIES:
			for i in range(enemies_hp.size()):
				if enemies_hp[i] > 0:
					_apply_status_to_enemy(i, skill.status_to_apply, stacks)

	_after_player_action()


# ───────────────────────────────────────────────────
# Enemy Actions & Effects
# ───────────────────────────────────────────────────

func _make_enemy_action_from_choice(
	enemy_index: int,
	skill_index: int,
	target_index: int
) -> Dictionary:
	var action := {
		"source": "enemy",
		"source_index": enemy_index,
		"skill": null,
		"skill_index": skill_index,
		"target_index": target_index,
	}

	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return action

	var enemy_data := enemies_data[enemy_index]

	if skill_index >= 0 and skill_index < enemy_data.skills.size():
		var skill := enemy_data.skills[skill_index]
		action["skill"] = skill

	return action


func _apply_enemy_action(action: Dictionary) -> void:
	var enemy_index: int = action.get("source_index", -1)
	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return

	var enemy_data := enemies_data[enemy_index]
	var skill: SkillData = action.get("skill", null)

	if skill != null:
		_enemy_use_skill(enemy_index, skill)
	else:
		# Basic attack fallback
		_apply_damage_to_player(enemy_data.attack_power)


func _enemy_use_skill(enemy_index: int, skill: SkillData) -> void:
	if skill is DamageSkillData:
		_enemy_damage_skill(enemy_index, skill as DamageSkillData)
	elif skill is HealSkillData:
		_enemy_heal_skill(enemy_index, skill as HealSkillData)
	elif skill is StatusSkillData:
		_enemy_status_skill(enemy_index, skill as StatusSkillData)


func _enemy_damage_skill(enemy_index: int, skill: DamageSkillData) -> void:
	# For now enemies only target the player with damage
	_apply_damage_to_player(skill.power)

	# ── NEW: apply status if defined ───────────────────
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		# Interpretation:
		# - SELF     → buff itself
		# - others  → debuff player
		match skill.target_type:
			SkillData.TargetType.SELF:
				_apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)
			_:
				_apply_status_to_player(skill.status_to_apply, stacks)


func _enemy_heal_skill(enemy_index: int, skill: HealSkillData) -> void:
	if enemy_index < 0 or enemy_index >= enemies_hp.size():
		return

	var max_hp := enemies_data[enemy_index].max_hp
	enemies_hp[enemy_index] = min(enemies_hp[enemy_index] + skill.power, max_hp)

	# ── NEW: apply status if defined ───────────────────
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		# For now, all enemy heals are self/boss-side effects
		match skill.target_type:
			SkillData.TargetType.SELF:
				_apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)
			SkillData.TargetType.ALL_ENEMIES:
				# when you add multi-enemy battles on enemy side, adjust
				_apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)
			SkillData.TargetType.SINGLE_ENEMY:
				# future: targeted ally heals
				_apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)


func _enemy_status_skill(enemy_index: int, skill: StatusSkillData) -> void:
	if skill == null:
		return
	if skill.status_to_apply == null:
		return

	var stacks: int = max(1, int(skill.status_stacks))

	match skill.target_type:
		SkillData.TargetType.SELF:
			# Self-buff / self-debuff
			_apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)

		SkillData.TargetType.SINGLE_ENEMY, SkillData.TargetType.ALL_ENEMIES:
			# Only one player for now, so both target types hit the player
			_apply_status_to_player(skill.status_to_apply, stacks)

# ───────────────────────────────────────────────────
# Helpers & AI
# ───────────────────────────────────────────────────

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


func _choose_enemy_action(enemy_index: int) -> Dictionary:
	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return {
			"skill_index": -1,
			"target_index": -1,
		}

	var brain_id: StringName = enemies_data[enemy_index].ai_brain_id
	return EnemyAI.choose_action(
		brain_id,
		enemy_index,
		enemies_data,
		enemies_hp,
		player_hp
	)

func _build_turn_queue() -> void:
	_turn_queue.clear()

	# Player entry
	if player_data != null:
		var player_speed: int = player_data.speed
		var player_entry: Dictionary = {
			"side": Turn.PLAYER,
			"enemy_index": -1,
			"speed": player_speed,
		}
		_turn_queue.append(player_entry)

	# Enemy entries
	for i in range(enemies_data.size()):
		var enemy_data: CombatantData = enemies_data[i]
		var spd: int = enemy_data.speed
		var entry: Dictionary = {
			"side": Turn.ENEMY,
			"enemy_index": i,
			"speed": spd,
		}
		_turn_queue.append(entry)

	_turn_queue.sort_custom(Callable(self, "_compare_turn_entry_by_speed"))
	_turn_queue_index = -1


func _compare_turn_entry_by_speed(a: Dictionary, b: Dictionary) -> bool:
	var sa: int = int(a.get("speed", 0))
	var sb: int = int(b.get("speed", 0))
	# Higher speed acts first
	return sa > sb


func _start_first_turn() -> void:
	if _turn_queue.is_empty():
		return
	_advance_turn()


# ───────────────────────────────────────────────────
# Status Effects: Add / Tick / Aggregate
# ───────────────────────────────────────────────────

func _apply_status_to_player(effect_data: StatusEffectData, add_stacks: int = 1) -> void:
	if effect_data == null or add_stacks <= 0:
		return

	var effects: Array = player_status.get("effects", []) as Array
	var entry: Dictionary = _find_status_entry(effects, effect_data.id)

	if entry.is_empty():
		var duration: int = effect_data.base_duration_turns
		if effect_data.is_indefinite:
			duration = -1  # sentinel for "never expires"

		entry = {
			"data": effect_data,
			"remaining_turns": duration,
			"stacks": clamp(add_stacks, 1, effect_data.max_stacks),
		}
		effects.append(entry)
	else:
		var current_stacks: int = int(entry.get("stacks", 1))
		var new_stacks: int = clamp(current_stacks + add_stacks, 1, effect_data.max_stacks)
		entry["stacks"] = new_stacks

		# Only refresh duration if this is not indefinite
		var current_turns: int = int(entry.get("remaining_turns", 0))
		if not effect_data.is_indefinite:
			var base_duration: int = effect_data.base_duration_turns
			entry["remaining_turns"] = max(current_turns, base_duration)


	player_status["effects"] = effects
	_recalculate_player_defense()


func _apply_status_to_enemy(enemy_index: int, effect_data: StatusEffectData, add_stacks: int = 1) -> void:
	if effect_data == null or add_stacks <= 0:
		return
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index] as Dictionary
	var effects: Array = status.get("effects", []) as Array
	var entry: Dictionary = _find_status_entry(effects, effect_data.id)

	if entry.is_empty():
		var duration: int = effect_data.base_duration_turns
		if effect_data.is_indefinite:
			duration = -1

		entry = {
			"data": effect_data,
			"remaining_turns": duration,
			"stacks": clamp(add_stacks, 1, effect_data.max_stacks),
		}
		effects.append(entry)
	else:
		var current_stacks: int = int(entry.get("stacks", 1))
		var new_stacks: int = clamp(current_stacks + add_stacks, 1, effect_data.max_stacks)
		entry["stacks"] = new_stacks

		var current_turns: int = int(entry.get("remaining_turns", 0))
		if not effect_data.is_indefinite:
			var base_duration: int = effect_data.base_duration_turns
			entry["remaining_turns"] = max(current_turns, base_duration)


	status["effects"] = effects
	enemies_status[enemy_index] = status
	_recalculate_enemy_defense(enemy_index)


func _find_status_entry(effects: Array, effect_id: StringName) -> Dictionary:
	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data != null and data.id == effect_id:
			return dict
	return {}  # empty dict = "not found"


func _recalculate_player_defense() -> void:
	var base_factor: float = 1.0
	var effects: Array = player_status.get("effects", []) as Array

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		var stacks: int = int(dict.get("stacks", 1))
		if data != null:
			for _i in range(stacks):
				base_factor *= data.defense_multiplier_per_stack

	player_status["defense_factor"] = base_factor


func _recalculate_enemy_defense(enemy_index: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index] as Dictionary
	var base_factor: float = 1.0
	var effects: Array = status.get("effects", []) as Array

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		var stacks: int = int(dict.get("stacks", 1))
		if data != null:
			for _i in range(stacks):
				base_factor *= data.defense_multiplier_per_stack

	status["defense_factor"] = base_factor
	enemies_status[enemy_index] = status


func _tick_statuses_for_player(timing: int) -> void:
	var effects: Array = player_status.get("effects", []) as Array
	var new_effects: Array = []
	var total_dot: int = 0

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue

		# DOT
		if data.tick_timing == timing:
			var stacks: int = int(dict.get("stacks", 1))
			total_dot += data.dot_damage_per_stack * stacks

		# Duration
		if timing == StatusEffectData.TickTiming.OWNER_TURN_START:
			var remaining: int = int(dict.get("remaining_turns", 0))
			# -1 = indefinite, do not decrement
			if remaining > 0:
				remaining -= 1
				dict["remaining_turns"] = remaining

		var final_remaining: int = int(dict.get("remaining_turns", 0))
		if final_remaining > 0 or final_remaining < 0:
			new_effects.append(dict)


	player_status["effects"] = new_effects
	_recalculate_player_defense()

	if total_dot > 0:
		player_hp -= total_dot
		_emit_hp()


func _tick_statuses_for_enemy(enemy_index: int, timing: int) -> void:
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index] as Dictionary
	var effects: Array = status.get("effects", []) as Array
	var new_effects: Array = []
	var total_dot: int = 0

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue

		if data.tick_timing == timing:
			var stacks: int = int(dict.get("stacks", 1))
			total_dot += data.dot_damage_per_stack * stacks

		if timing == StatusEffectData.TickTiming.OWNER_TURN_START:
			var remaining: int = int(dict.get("remaining_turns", 0))
			if remaining > 0:
				remaining -= 1
				dict["remaining_turns"] = remaining

		var final_remaining: int = int(dict.get("remaining_turns", 0))
		if final_remaining > 0 or final_remaining < 0:
			new_effects.append(dict)


	status["effects"] = new_effects
	enemies_status[enemy_index] = status
	_recalculate_enemy_defense(enemy_index)

	if total_dot > 0:
		enemies_hp[enemy_index] -= total_dot
		_emit_hp()


func _on_side_turn_started(is_player: bool) -> void:
	if is_player:
		_tick_statuses_for_player(StatusEffectData.TickTiming.OWNER_TURN_START)
	else:
		if _current_enemy_index >= 0:
			_tick_statuses_for_enemy(_current_enemy_index, StatusEffectData.TickTiming.OWNER_TURN_START)


func _remove_status_from_player(effect_id: StringName) -> void:
	var effects: Array = player_status.get("effects", []) as Array
	var new_effects: Array = []

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue
		if data.id == effect_id:
			continue  # skip = remove
		new_effects.append(dict)

	player_status["effects"] = new_effects
	_recalculate_player_defense()


func _remove_status_from_enemy(enemy_index: int, effect_id: StringName) -> void:
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index] as Dictionary
	var effects: Array = status.get("effects", []) as Array
	var new_effects: Array = []

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue
		if data.id == effect_id:
			continue
		new_effects.append(dict)

	status["effects"] = new_effects
	enemies_status[enemy_index] = status
	_recalculate_enemy_defense(enemy_index)
