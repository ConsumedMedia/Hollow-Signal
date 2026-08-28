class_name AbilityDefinition
extends Resource
## Authored damaging attack. Move and Wait are universal rules, not class skills.

@export var id: StringName = &""
@export var display_name: String = ""
@export var actor_ranks: Array[int] = [1, 2]
@export var target_ranks: Array[int] = [1, 2]
@export_range(1, 1000) var damage_min: int = 6
@export_range(1, 1000) var damage_max: int = 8


func is_valid() -> bool:
	return not id.is_empty() and id not in [&"move", &"wait"] and not display_name.is_empty() \
		and _valid_ranks(actor_ranks) and _valid_ranks(target_ranks) \
		and damage_min > 0 and damage_max >= damage_min


func _valid_ranks(ranks: Array[int]) -> bool:
	if ranks.is_empty():
		return false
	var seen: Array[int] = []
	for rank: int in ranks:
		if rank < 1 or rank > 4 or rank in seen:
			return false
		seen.append(rank)
	return true
