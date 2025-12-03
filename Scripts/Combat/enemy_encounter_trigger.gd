extends Area3D

signal combat_requested(encounter: EncounterData)

@export var encounter_data: EncounterData

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	print("TRIGGER FIRED on ", self, " encounter_data = ", encounter_data)
	combat_requested.emit(encounter_data)

	monitoring = false
	monitorable = false
