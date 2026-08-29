class_name ModuleDefinition
extends Resource
## Authored equipment values; ownership and assignment live in CampaignState/CrewState.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var health_bonus: int = 0
@export var speed_bonus: int = 0
@export var damage_bonus: int = 0
@export var healing_bonus: int = 0
@export var strain_relief_bonus: int = 0
@export var starting_power_bonus: int = 0


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and not description.is_empty()
