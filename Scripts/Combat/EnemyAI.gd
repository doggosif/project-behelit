extends Object
class_name EnemyAI

static func choose_action(
	brain_id: StringName,
	enemy_index: int,
	enemies_data: Array[CombatantData],
	enemies_hp: Array[int],
	player_hp: int
) -> Dictionary:
	# Base fallback: basic attack against player
	var action := {
		"skill_index": -1,   # -1 = basic attack
		"target_index": -1   # -1 = player (you only have one target side for now)
	}

	if enemy_index < 0 or enemy_index >= enemies_data.size():
		return action

	var enemy_data := enemies_data[enemy_index]
	var enemy_hp := enemies_hp[enemy_index]
	var enemy_hp_ratio: float = 1.0
	if enemy_data.max_hp > 0:
		enemy_hp_ratio = float(enemy_hp) / float(enemy_data.max_hp)

	match brain_id:
		"default":
			return _choose_default(enemy_data, action)

		"coward":
			return _choose_coward(enemy_data, action, enemy_hp_ratio)

		"bruiser":
			return _choose_bruiser(enemy_data, action)

		_:
			# Unknown brain id: fall back to default
			return _choose_default(enemy_data, action)


static func _choose_default(enemy_data: CombatantData, base_action: Dictionary) -> Dictionary:
	var action := base_action

	if enemy_data.skills.size() > 0:
		action.skill_index = 0

	return action


static func _choose_coward(
	enemy_data: CombatantData,
	base_action: Dictionary,
	hp_ratio: float
) -> Dictionary:
	var action := base_action

	# If below 50% hp and has a heal skill, use it
	if hp_ratio < 0.5:
		var heal_index := _find_first_heal_skill(enemy_data)
		if heal_index != -1:
			action.skill_index = heal_index
			return action

	# Otherwise behave like default
	return _choose_default(enemy_data, base_action)


static func _choose_bruiser(
	enemy_data: CombatantData,
	base_action: Dictionary
) -> Dictionary:
	var action := base_action

	# Prefer a damage skill if any exists
	var dmg_index := _find_first_damage_skill(enemy_data)
	if dmg_index != -1:
		action.skill_index = dmg_index
		return action

	# No damage skill? Fall back to default behavior.
	return _choose_default(enemy_data, base_action)


static func _find_first_heal_skill(enemy_data: CombatantData) -> int:
	for i in range(enemy_data.skills.size()):
		var s := enemy_data.skills[i]
		if s is HealSkillData:
			return i
	return -1


static func _find_first_damage_skill(enemy_data: CombatantData) -> int:
	for i in range(enemy_data.skills.size()):
		var s := enemy_data.skills[i]
		if s is DamageSkillData:
			return i
	return -1
