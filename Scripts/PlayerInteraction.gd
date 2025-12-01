class_name PlayerInteraction
extends Node3D

@export var input_source: PlayerInput
@export var interaction_ray: RayCast3D

func _physics_process(delta: float) -> void:
	if input_source == null or interaction_ray == null:
		return

	if input_source.interact_pressed:
		input_source.interact_pressed = false
		_try_interact()


func _try_interact() -> void:
	if not interaction_ray.is_colliding():
		return

	var hit = interaction_ray.get_collider()
	if hit == null:
		return

	var interact_target := _find_interactable(hit)
	if interact_target:
		interact_target.interact(self)
		#print("Interacted with ", interact_target.name)
	#else:
		#print("Nothing interactable found up the chain.")


func _find_interactable(start: Node) -> Node:
	var current: Node = start
	while current:
		if current.has_method("interact"):
			return current
		current = current.get_parent()
	return null
