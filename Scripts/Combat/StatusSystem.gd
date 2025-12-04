extends Object
class_name StatusSystem

func apply_to_player(status: Dictionary, effect_data: StatusEffectData, add_stacks: int) -> void:
	_apply_to_status(status, effect_data, add_stacks)


func apply_to_enemy(status: Dictionary, effect_data: StatusEffectData, add_stacks: int) -> void:
	_apply_to_status(status, effect_data, add_stacks)


func tick_player(status: Dictionary, timing: int) -> int:
	return _tick_statuses(status, timing)


func tick_enemy(status: Dictionary, timing: int) -> int:
	return _tick_statuses(status, timing)


func remove_from_player(status: Dictionary, effect_id: StringName) -> void:
	_remove_from_status(status, effect_id)


func remove_from_enemy(status: Dictionary, effect_id: StringName) -> void:
	_remove_from_status(status, effect_id)


# ───────────────────────────────────────────────────
# Internal shared helpers
# ───────────────────────────────────────────────────

func _apply_to_status(status: Dictionary, effect_data: StatusEffectData, add_stacks: int) -> void:
	if effect_data == null:
		return
	if add_stacks <= 0:
		return

	var effects: Array = []
	if status.has("effects"):
		effects = status.get("effects", []) as Array

	var entry: Dictionary = _find_status_entry(effects, effect_data.id)

	if entry.is_empty():
		var duration: int = effect_data.base_duration_turns
		if effect_data.is_indefinite:
			duration = -1  # sentinel for "never expires"

		entry = {
			"data": effect_data,
			"remaining_turns": duration,
			"stacks": clamp(add_stacks, 1, effect_data.max_stacks),
		}
		effects.append(entry)
	else:
		var current_stacks: int = int(entry.get("stacks", 1))
		var new_stacks: int = clamp(current_stacks + add_stacks, 1, effect_data.max_stacks)
		entry["stacks"] = new_stacks

		# Only refresh duration if this is not indefinite
		var current_turns: int = int(entry.get("remaining_turns", 0))
		if not effect_data.is_indefinite:
			var base_duration: int = effect_data.base_duration_turns
			entry["remaining_turns"] = max(current_turns, base_duration)

	status["effects"] = effects
	_recalculate_defense(status)


func _tick_statuses(status: Dictionary, timing: int) -> int:
	var effects: Array = status.get("effects", []) as Array
	var new_effects: Array = []
	var total_dot: int = 0

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue

		# DOT
		if data.tick_timing == timing:
			var stacks: int = int(dict.get("stacks", 1))
			total_dot += data.dot_damage_per_stack * stacks

		# Duration
		if timing == StatusEffectData.TickTiming.OWNER_TURN_START:
			var remaining: int = int(dict.get("remaining_turns", 0))
			# -1 = indefinite, do not decrement
			if remaining > 0:
				remaining -= 1
				dict["remaining_turns"] = remaining

		var final_remaining: int = int(dict.get("remaining_turns", 0))
		if final_remaining > 0 or final_remaining < 0:
			new_effects.append(dict)

	status["effects"] = new_effects
	_recalculate_defense(status)
	return total_dot


func _remove_from_status(status: Dictionary, effect_id: StringName) -> void:
	var effects: Array = status.get("effects", []) as Array
	var new_effects: Array = []

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue
		if data.id == effect_id:
			continue  # skip = remove
		new_effects.append(dict)

	status["effects"] = new_effects
	_recalculate_defense(status)


func _find_status_entry(effects: Array, effect_id: StringName) -> Dictionary:
	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data != null and data.id == effect_id:
			return dict
	return {}  # empty dict = "not found"


func _recalculate_defense(status: Dictionary) -> void:
	var base_factor: float = 1.0
	var effects: Array = status.get("effects", []) as Array

	for e in effects:
		var dict: Dictionary = e as Dictionary
		var data: StatusEffectData = dict.get("data", null)
		if data == null:
			continue
		var stacks: int = int(dict.get("stacks", 1))
		for _i in range(stacks):
			base_factor *= data.defense_multiplier_per_stack

	status["defense_factor"] = base_factor
