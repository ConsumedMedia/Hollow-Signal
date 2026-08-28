class_name CrewState
extends RefCounted
## Persistent in-memory individual; never stored in an authored Resource.

var id: StringName
var definition: ActorDefinition
var health: int
var strain: int = 0
var shaken: bool = false
var dead: bool = false


func _init(crew_id: StringName, actor_definition: ActorDefinition) -> void:
	id = crew_id
	definition = actor_definition
	health = definition.max_health
