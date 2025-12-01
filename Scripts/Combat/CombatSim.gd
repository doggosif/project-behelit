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

signal hp_changed(player_hp: int, enemies_hp: Array[int])
signal turn_changed(current_turn: Turn)
signal combat_finished(result: CombatResult)


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

	for e in enemies_data:
		enemies_hp.append(e.max_hp)

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

	for i in range(enemies_data.size()):
		if enemies_hp[i] > 0:
			player_hp -= enemies_data[i].attack_power

	_emit_hp()

	if player_hp <= 0:
		_emit_result(false)
		return

	current_turn = Turn.PLAYER
	_emit_turn()


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
	if current_turn != Turn.PLAYER:
		return

	if target_index < 0 or target_index >= enemies_hp.size():
		return

	# must be alive
	if enemies_hp[target_index] <= 0:
		return

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
