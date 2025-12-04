extends Object
class_name SkillResolver

# Player side ----------------------------------------------------

func make_player_action_from_skill(sim, skill_index: int, target_index: int) -> Dictionary:
	var action: Dictionary = {
		"source": "player",
		"source_index": -1,
		"skill": null,
		"skill_index": skill_index,
		"target_index": target_index,
	}

	if sim.player_data == null:
		return action

	if skill_index < 0 or skill_index >= sim.player_data.skills.size():
		return action

	var skill: SkillData = sim.player_data.skills[skill_index]
	action["skill"] = skill

	return action


func apply_player_action(sim, action: Dictionary) -> void:
	var skill: SkillData = action.get("skill", null)
	var skill_index: int = int(action.get("skill_index", -1))
	var target_index: int = int(action.get("target_index", -1))

	if skill == null:
		# Optional: basic attack fallback when skill_index == -1
		if skill_index == -1 and sim.player_data != null:
			var target: int = sim._get_first_alive_enemy_index()
			if target != -1:
				sim.enemies_hp[target] -= sim.player_data.attack_power
				sim._after_player_action()
		return

	if skill is DamageSkillData:
		_player_skill_damage(sim, skill as DamageSkillData, target_index)
	elif skill is HealSkillData:
		_player_skill_heal(sim, skill as HealSkillData)
	elif skill is StatusSkillData:
		_player_status_skill(sim, skill as StatusSkillData, target_index)


func _player_skill_damage(sim, skill: DamageSkillData, target_index: int) -> void:
	# Direct damage
	match skill.target_type:
		SkillData.TargetType.SINGLE_ENEMY:
			if target_index < 0 or target_index >= sim.enemies_hp.size():
				return
			if sim.enemies_hp[target_index] <= 0:
				return
			sim.enemies_hp[target_index] -= skill.power

		SkillData.TargetType.ALL_ENEMIES:
			for i in range(sim.enemies_hp.size()):
				if sim.enemies_hp[i] > 0:
					sim.enemies_hp[i] -= skill.power

		SkillData.TargetType.SELF:
			sim.player_hp -= skill.power  # edgy self-harm

	# Status application, if any
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		match skill.target_type:
			SkillData.TargetType.SINGLE_ENEMY:
				if target_index >= 0 and target_index < sim.enemies_hp.size():
					sim._apply_status_to_enemy(target_index, skill.status_to_apply, stacks)

			SkillData.TargetType.ALL_ENEMIES:
				for i in range(sim.enemies_hp.size()):
					if sim.enemies_hp[i] > 0:
						sim._apply_status_to_enemy(i, skill.status_to_apply, stacks)

			SkillData.TargetType.SELF:
				sim._apply_status_to_player(skill.status_to_apply, stacks)

	sim._after_player_action()


func _player_skill_heal(sim, skill: HealSkillData) -> void:
	match skill.target_type:
		SkillData.TargetType.SELF:
			if sim.player_data != null:
				var max_hp: int = sim.player_data.max_hp
				sim.player_hp = min(sim.player_hp + skill.power, max_hp)

		SkillData.TargetType.ALL_ENEMIES:
			for i in range(sim.enemies_hp.size()):
				var max_hp_enemy: int = sim.enemies_data[i].max_hp
				sim.enemies_hp[i] = min(sim.enemies_hp[i] + skill.power, max_hp_enemy)

		SkillData.TargetType.SINGLE_ENEMY:
			# future: heal ally
			pass

	# Status application, if any
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		match skill.target_type:
			SkillData.TargetType.SELF:
				sim._apply_status_to_player(skill.status_to_apply, stacks)

			SkillData.TargetType.ALL_ENEMIES:
				for i in range(sim.enemies_hp.size()):
					sim._apply_status_to_enemy(i, skill.status_to_apply, stacks)

			SkillData.TargetType.SINGLE_ENEMY:
				# when you add ally targeting, apply there
				pass

	sim._after_player_action()


func _player_status_skill(sim, skill: StatusSkillData, target_index: int) -> void:
	if skill.status_to_apply == null:
		sim._after_player_action()
		return

	var stacks: int = max(1, int(skill.status_stacks))

	match skill.target_type:
		SkillData.TargetType.SELF:
			sim._apply_status_to_player(skill.status_to_apply, stacks)

		SkillData.TargetType.SINGLE_ENEMY:
			if target_index >= 0 and target_index < sim.enemies_hp.size():
				sim._apply_status_to_enemy(target_index, skill.status_to_apply, stacks)

		SkillData.TargetType.ALL_ENEMIES:
			for i in range(sim.enemies_hp.size()):
				if sim.enemies_hp[i] > 0:
					sim._apply_status_to_enemy(i, skill.status_to_apply, stacks)

	sim._after_player_action()


# Enemy side -----------------------------------------------------

func make_enemy_action_from_choice(sim, enemy_index: int, skill_index: int, target_index: int) -> Dictionary:
	var action: Dictionary = {
		"source": "enemy",
		"source_index": enemy_index,
		"skill": null,
		"skill_index": skill_index,
		"target_index": target_index,
	}

	if enemy_index < 0 or enemy_index >= sim.enemies_data.size():
		return action

	var enemy_data: CombatantData = sim.enemies_data[enemy_index]

	if skill_index >= 0 and skill_index < enemy_data.skills.size():
		var skill: SkillData = enemy_data.skills[skill_index]
		action["skill"] = skill

	return action


func apply_enemy_action(sim, action: Dictionary) -> void:
	var enemy_index: int = int(action.get("source_index", -1))
	if enemy_index < 0 or enemy_index >= sim.enemies_data.size():
		return

	var enemy_data: CombatantData = sim.enemies_data[enemy_index]
	var skill: SkillData = action.get("skill", null)

	if skill != null:
		_enemy_use_skill(sim, enemy_index, skill)
	else:
		# Basic attack fallback
		sim._apply_damage_to_player(enemy_data.attack_power)


func _enemy_use_skill(sim, enemy_index: int, skill: SkillData) -> void:
	if skill is DamageSkillData:
		_enemy_damage_skill(sim, enemy_index, skill as DamageSkillData)
	elif skill is HealSkillData:
		_enemy_heal_skill(sim, enemy_index, skill as HealSkillData)
	elif skill is StatusSkillData:
		_enemy_status_skill(sim, enemy_index, skill as StatusSkillData)


func _enemy_damage_skill(sim, enemy_index: int, skill: DamageSkillData) -> void:
	# For now enemies only target the player with damage
	sim._apply_damage_to_player(skill.power)

	# Status application, if any
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		# Interpretation:
		# - SELF → buff itself
		# - others → debuff player
		match skill.target_type:
			SkillData.TargetType.SELF:
				sim._apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)
			_:
				sim._apply_status_to_player(skill.status_to_apply, stacks)


func _enemy_heal_skill(sim, enemy_index: int, skill: HealSkillData) -> void:
	if enemy_index < 0 or enemy_index >= sim.enemies_hp.size():
		return

	var max_hp: int = sim.enemies_data[enemy_index].max_hp
	sim.enemies_hp[enemy_index] = min(sim.enemies_hp[enemy_index] + skill.power, max_hp)

	# Status application, if any
	if skill.status_to_apply:
		var stacks: int = max(1, int(skill.status_stacks))
		# For now, all enemy heals are self-side effects
		match skill.target_type:
			SkillData.TargetType.SELF:
				sim._apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)
			SkillData.TargetType.ALL_ENEMIES:
				# when/if you add multi-enemy parties on enemy side, adjust
				sim._apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)
			SkillData.TargetType.SINGLE_ENEMY:
				# future: targeted ally heals
				sim._apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)


func _enemy_status_skill(sim, enemy_index: int, skill: StatusSkillData) -> void:
	if skill.status_to_apply == null:
		return

	var stacks: int = max(1, int(skill.status_stacks))

	match skill.target_type:
		SkillData.TargetType.SELF:
			# Self-buff / self-debuff
			sim._apply_status_to_enemy(enemy_index, skill.status_to_apply, stacks)

		SkillData.TargetType.SINGLE_ENEMY, SkillData.TargetType.ALL_ENEMIES:
			# Only one player for now, so both target types hit the player
			sim._apply_status_to_player(skill.status_to_apply, stacks)
