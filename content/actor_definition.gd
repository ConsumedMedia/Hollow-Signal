class_name ActorDefinition
extends Resource
## Authored, shared data. Never write an individual's current health here.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(1, 1000) var max_health: int = 30
@export_range(0, 100) var speed: int = 6
@export var abilities: Array[AbilityDefinition] = []


func is_valid() -> bool:
	if id.is_empty() or display_name.is_empty() or max_health <= 0 or speed < 0:
		return false
	var seen: Array[StringName] = []
	for ability: AbilityDefinition in abilities:
		if ability == null or not ability.is_valid() or ability.id in seen:
			return false
		seen.append(ability.id)
	return true


func get_ability(ability_id: StringName) -> AbilityDefinition:
	for ability: AbilityDefinition in abilities:
		if ability.id == ability_id:
			return ability
	return null
