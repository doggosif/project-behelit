extends HBoxContainer
class_name SkillBarUI

signal skill_selected(index: int)

var _selected_index: int = 0


func build_from_player_data(player_data: CombatantData) -> void:
	# Clear previous buttons
	for child in get_children():
		child.queue_free()

	_selected_index = 0

	if player_data == null:
		push_error("SkillBarUI: player_data is null.")
		return

	var skills: Array[SkillData] = player_data.skills
	if skills.is_empty():
		return

	for i in range(skills.size()):
		var skill: SkillData = skills[i]
		if skill == null:
			continue

		var btn := Button.new()
		btn.text = skill.display_name
		btn.toggle_mode = true
		btn.button_pressed = (i == _selected_index)
		btn.pressed.connect(_on_button_pressed.bind(i))
		add_child(btn)


func _on_button_pressed(index: int) -> void:
	_selected_index = index

	for j in range(get_child_count()):
		var btn: Button = get_child(j) as Button
		btn.button_pressed = (j == index)

	skill_selected.emit(index)


func get_selected_index() -> int:
	return _selected_index
