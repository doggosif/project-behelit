extends Control
class_name CombatUI

@export var sim: CombatSim

signal skill_requested(skill_index: int, target_index: int)

@onready var info_label: Label = $InfoLabel
@onready var player_hp_label: Label = $PlayerHPLabel
@onready var enemy_list_ui: EnemyListUI = $EnemyListUI
@onready var skill_bar_ui: SkillBarUI = $SkillBarUI
@onready var player_button: Button = $PlayerButton

var _selected_skill_index: int = 0


func _ready() -> void:
	if sim == null:
		push_error("CombatUI has no sim assigned.")
		return

	if enemy_list_ui == null:
		push_error("CombatUI: enemy_list_ui is null.")
		return
	if skill_bar_ui == null:
		push_error("CombatUI: skill_bar_ui is null.")
		return
	if player_button == null:
		push_error("CombatUI: player_button is null.")
		return

	sim.hp_changed.connect(_on_hp_changed)
	sim.turn_changed.connect(_on_turn_changed)
	sim.combat_finished.connect(_on_combat_finished)

	if sim.player_data:
		skill_bar_ui.build_from_player_data(sim.player_data)
		skill_bar_ui.skill_selected.connect(_on_skill_selected)

	enemy_list_ui.enemy_clicked.connect(_on_enemy_clicked)
	player_button.pressed.connect(_on_player_button_pressed)

	# Start with correct lock state
	_set_player_input_enabled(sim.current_turn == CombatSim.Turn.PLAYER)


func _on_skill_selected(index: int) -> void:
	_selected_skill_index = index


func _on_hp_changed(player_hp: int, enemies_hp: Array[int]) -> void:
	player_hp_label.text = "Player HP: %d" % player_hp
	enemy_list_ui.update_enemies(enemies_hp)


func _on_turn_changed(current_turn: CombatSim.Turn) -> void:
	var is_player_turn: bool = (current_turn == CombatSim.Turn.PLAYER)

	match current_turn:
		CombatSim.Turn.PLAYER:
			info_label.text = "Your turn"
		CombatSim.Turn.ENEMY:
			info_label.text = "Enemy turn"

	_set_player_input_enabled(is_player_turn)


func _set_player_input_enabled(enabled: bool) -> void:
	# Skill bar buttons
	for i in range(skill_bar_ui.get_child_count()):
		var btn_node: Node = skill_bar_ui.get_child(i)
		if btn_node is Button:
			var btn := btn_node as Button
			btn.disabled = not enabled

	# Enemy list buttons
	for i in range(enemy_list_ui.get_child_count()):
		var row_node: Node = enemy_list_ui.get_child(i)
		if row_node is HBoxContainer:
			var row := row_node as HBoxContainer
			var attack_btn_node := row.get_node_or_null("AttackButton")
			if attack_btn_node is Button:
				var attack_btn := attack_btn_node as Button
				attack_btn.disabled = not enabled

	# Player self button
	if player_button:
		player_button.disabled = not enabled


func _on_combat_finished(result: CombatResult) -> void:
	if result.player_survived:
		info_label.text = "Victory"
	else:
		info_label.text = "Defeat"

	_set_player_input_enabled(false)


func _on_enemy_clicked(index: int) -> void:
	var player_data := sim.player_data
	if player_data == null:
		return

	if _selected_skill_index < 0 or _selected_skill_index >= player_data.skills.size():
		return

	var skill := player_data.skills[_selected_skill_index]
	if skill == null:
		return

	var target_type: int

	if skill is DamageSkillData:
		target_type = (skill as DamageSkillData).target_type
	elif skill is HealSkillData:
		target_type = (skill as HealSkillData).target_type
	elif skill is DefendSkillData:
		target_type = (skill as DefendSkillData).target_type
	else:
		return

	match target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			skill_requested.emit(_selected_skill_index, index)
		SkillData.TargetType.ALL_ENEMIES, SkillData.TargetType.SELF:
			skill_requested.emit(_selected_skill_index, -1)


func _on_player_button_pressed() -> void:
	var player_data := sim.player_data
	if player_data == null:
		return

	if _selected_skill_index < 0 or _selected_skill_index >= player_data.skills.size():
		return

	var skill := player_data.skills[_selected_skill_index]
	if skill == null:
		return

	var target_type: int

	if skill is DamageSkillData:
		target_type = (skill as DamageSkillData).target_type
	elif skill is HealSkillData:
		target_type = (skill as HealSkillData).target_type
	elif skill is DefendSkillData:
		target_type = (skill as DefendSkillData).target_type
	else:
		return

	match target_type:
		SkillData.TargetType.SELF, SkillData.TargetType.ALL_ENEMIES:
			skill_requested.emit(_selected_skill_index, -1)
		SkillData.TargetType.SINGLE_ENEMY:
			# For now, ignore self-button for single-target skills
			return
