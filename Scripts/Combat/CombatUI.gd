extends Control

@export var sim: CombatSim

@onready var info_label: Label = $InfoLabel
@onready var player_hp_label: Label = $PlayerHPLabel
@onready var enemy_hp_label: Label = $EnemyHPLabel   # temp
@onready var attack_button: Button = $AttackButton    # can keep for "hit first alive"
@onready var enemy_list: VBoxContainer = $EnemyList

var _enemy_count: int = 0


func _ready() -> void:
	# Connect to sim signals
	sim.hp_changed.connect(_on_hp_changed)
	sim.turn_changed.connect(_on_turn_changed)
	sim.combat_finished.connect(_on_combat_finished)

	attack_button.pressed.connect(_on_attack_pressed)

func _on_hp_changed(player_hp: int, enemies_hp: Array[int]) -> void:
	player_hp_label.text = "Player HP: %d" % player_hp
	enemy_hp_label.text = "Enemies HP: %s" % [str(enemies_hp)]  # keep for debug

	# First time: build enemy rows
	if _enemy_count == 0 and enemies_hp.size() > 0:
		_build_enemy_rows(enemies_hp.size())

	# Update each row’s label & disabled state
	for i in range(min(_enemy_count, enemies_hp.size())):
		var row := enemy_list.get_child(i)
		var label := row.get_node("Label") as Label
		var btn := row.get_node("AttackButton") as Button

		var hp := enemies_hp[i]
		label.text = "Enemy %d HP: %d" % [i, hp]
		btn.disabled = hp <= 0


func _on_turn_changed(current_turn: int) -> void:
	match current_turn:
		sim.Turn.PLAYER:
			info_label.text = "Your turn"
			attack_button.disabled = false
		sim.Turn.ENEMY:
			info_label.text = "Enemy turn..."
			attack_button.disabled = true

func _on_combat_finished(winner: String) -> void:
	attack_button.disabled = true
	if winner == "player":
		info_label.text = "You win."
	else:
		info_label.text = "You die."

func _on_attack_pressed() -> void:
	sim.player_attack()

func _clear_enemy_list() -> void:
	for child in enemy_list.get_children():
		child.queue_free()

func _build_enemy_rows(count: int) -> void:
	_clear_enemy_list()
	_enemy_count = count

	for i in range(count):
		var row := HBoxContainer.new()

		var label := Label.new()
		label.name = "Label"
		label.text = "Enemy %d HP: ?" % i

		var btn := Button.new()
		btn.name = "AttackButton"
		btn.text = "Hit %d" % i
		# connect with index bound
		btn.pressed.connect(_on_enemy_attack_button_pressed.bind(i))

		row.add_child(label)
		row.add_child(btn)
		enemy_list.add_child(row)

func _on_enemy_attack_button_pressed(index: int) -> void:
	sim.player_attack_target(index)
