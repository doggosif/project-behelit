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

var _status_system: StatusSystem = StatusSystem.new()
var _timeline: Timeline = Timeline.new()
var _skill_resolver: SkillResolver = SkillResolver.new()

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
	var num_slots: int = _timeline.get_size()
	if num_slots == 0:
		return

	# Try to find next alive actor, at most num_slots steps
	for step in range(num_slots):
		var entry: Dictionary = _timeline.next_entry()
		if entry.is_empty():
			continue

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
	return _skill_resolver.make_player_action_from_skill(self, skill_index, target_index)

func _apply_player_action(action: Dictionary) -> void:
	_skill_resolver.apply_player_action(self, action)

func _apply_damage_to_player(amount: int) -> void:
	var defense_factor: float = player_status.get("defense_factor", 1.0)
	var final_damage := int(round(amount * defense_factor))
	if final_damage < 0:
		final_damage = 0
	player_hp -= final_damage

# ───────────────────────────────────────────────────
# Enemy Actions & Effects
# ───────────────────────────────────────────────────

func _make_enemy_action_from_choice(
	enemy_index: int,
	skill_index: int,
	target_index: int
) -> Dictionary:
	return _skill_resolver.make_enemy_action_from_choice(self, enemy_index, skill_index, target_index)

func _apply_enemy_action(action: Dictionary) -> void:
	_skill_resolver.apply_enemy_action(self, action)

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
	var entries: Array = []

	# Player entry
	if player_data != null:
		var player_speed: int = player_data.speed
		var player_entry: Dictionary = {
			"side": Turn.PLAYER,
			"enemy_index": -1,
			"speed": player_speed,
		}
		entries.append(player_entry)

	# Enemy entries
	for i in range(enemies_data.size()):
		var enemy_data: CombatantData = enemies_data[i]
		var spd: int = enemy_data.speed
		var entry: Dictionary = {
			"side": Turn.ENEMY,
			"enemy_index": i,
			"speed": spd,
		}
		entries.append(entry)

	_timeline.build(entries)

func _start_first_turn() -> void:
	if _timeline.get_size() == 0:
		return
	_advance_turn()

# ───────────────────────────────────────────────────
# Status Effects: Add / Tick / Aggregate
# ───────────────────────────────────────────────────

func _on_side_turn_started(is_player: bool) -> void:
	if is_player:
		var dot: int = _status_system.tick_player(
			player_status,
			StatusEffectData.TickTiming.OWNER_TURN_START
		)
		if dot > 0:
			player_hp -= dot
			_emit_hp()
	else:
		if _current_enemy_index >= 0 and _current_enemy_index < enemies_status.size():
			var status: Dictionary = enemies_status[_current_enemy_index]
			var dot_enemy: int = _status_system.tick_enemy(
				status,
				StatusEffectData.TickTiming.OWNER_TURN_START
			)
			enemies_status[_current_enemy_index] = status

			if dot_enemy > 0:
				enemies_hp[_current_enemy_index] -= dot_enemy
				_emit_hp()

# ───────────────────────────────────────────────────
# Status: thin wrappers around StatusSystem
# ───────────────────────────────────────────────────

func _apply_status_to_player(effect_data: StatusEffectData, add_stacks: int = 1) -> void:
	_status_system.apply_to_player(player_status, effect_data, add_stacks)

func _apply_status_to_enemy(enemy_index: int, effect_data: StatusEffectData, add_stacks: int = 1) -> void:
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index]
	_status_system.apply_to_enemy(status, effect_data, add_stacks)
	enemies_status[enemy_index] = status

func _remove_status_from_player(effect_id: StringName) -> void:
	_status_system.remove_from_player(player_status, effect_id)

func _remove_status_from_enemy(enemy_index: int, effect_id: StringName) -> void:
	if enemy_index < 0 or enemy_index >= enemies_status.size():
		return

	var status: Dictionary = enemies_status[enemy_index]
	_status_system.remove_from_enemy(status, effect_id)
	enemies_status[enemy_index] = status
