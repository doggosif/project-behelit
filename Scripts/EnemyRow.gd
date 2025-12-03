extends HBoxContainer
class_name EnemyRow

@onready var hp_label: Label = $HpLabel
@onready var attack_button: Button = $AttackButton

var enemy_index: int = -1

func setup(index: int) -> void:
	enemy_index = index
	attack_button.text = "Hit %d" % index

func set_hp(hp: int) -> void:
	hp_label.text = "Enemy %d HP: %d" % [enemy_index, hp]
	attack_button.disabled = hp <= 0
