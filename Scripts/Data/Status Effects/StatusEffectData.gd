extends Resource
class_name StatusEffectData

enum TickTiming {
	NONE,
	OWNER_TURN_START,
	OWNER_TURN_END,
}

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""

# How many of THIS SIDE'S turns it lasts.
@export var base_duration_turns: int = 1

# How many stacks of this effect can exist at once.
@export var max_stacks: int = 1

# When DOT / other ticking stuff happens.
@export var tick_timing: TickTiming = TickTiming.OWNER_TURN_START

@export var is_indefinite: bool = false

# ── Simple numeric knobs for now ────────────────────

# Each stack multiplies defense by this factor.
# Example: 0.5 with 1 stack = half damage taken.
@export var defense_multiplier_per_stack: float = 1.0

# Each stack deals this much HP damage to the OWNER when it ticks.
# Example: poison that hurts on owner's turn.
@export var dot_damage_per_stack: int = 0
