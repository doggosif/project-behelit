extends Button
class_name SkillButton

var skill_index: int = -1
var skill: SkillData = null

func setup(data: SkillData, index: int) -> void:
	skill = data
	skill_index = index
	text = data.display_name
	# You can also set icon, tooltip, etc. here
