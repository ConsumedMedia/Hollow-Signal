class_name ActorDefinition
extends Resource
## Authored, shared data. Never write an individual's current health here.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1, 1000) var max_health: int = 30
@export_range(1, 1000) var damage_min: int = 6
@export_range(1, 1000) var damage_max: int = 8


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and max_health > 0 \
		and damage_min > 0 and damage_max >= damage_min
