extends VBoxContainer
class_name EnemyListUI

signal enemy_clicked(index: int)

var _enemy_count: int = 0


func build_rows(count: int) -> void:
	_clear()
	_enemy_count = count

	for i in range(count):
		var row := HBoxContainer.new()

		var label := Label.new()
		label.name = "Label"
		label.text = "Enemy %d HP: ?" % i

		var btn := Button.new()
		btn.name = "AttackButton"
		btn.text = "Hit %d" % i
		btn.pressed.connect(_on_enemy_button_pressed.bind(i))

		row.add_child(label)
		row.add_child(btn)
		add_child(row)


func update_enemies(enemies_hp: Array[int]) -> void:
	# First time: build rows
	if _enemy_count == 0 and enemies_hp.size() > 0:
		build_rows(enemies_hp.size())

	var count: int = min(_enemy_count, enemies_hp.size())

	for i in range(count):
		var row := get_child(i)

		var label := row.get_node("Label") as Label
		var btn := row.get_node("AttackButton") as Button

		var hp := enemies_hp[i]
		label.text = "Enemy %d HP: %d" % [i, hp]
		btn.disabled = hp <= 0


func _on_enemy_button_pressed(index: int) -> void:
	enemy_clicked.emit(index)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_enemy_count = 0
