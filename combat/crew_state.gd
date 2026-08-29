class_name CrewState
extends RefCounted
## Persistent in-memory individual; never stored in an authored Resource.

var id: StringName
var definition: ActorDefinition
var call_sign: String
var health: int
var strain: int = 0
var shaken: bool = false
var dead: bool = false
var module_id: StringName = &""
var upgrade_health_bonus: int = 0


func _init(crew_id: StringName, actor_definition: ActorDefinition) -> void:
	id = crew_id
	definition = actor_definition
	call_sign = String(crew_id).to_upper()
	health = definition.max_health


func module() -> ModuleDefinition:
	return ContentCatalogue.get_module(module_id)


func max_health() -> int:
	var equipped: ModuleDefinition = module()
	return definition.max_health + upgrade_health_bonus + (equipped.health_bonus if equipped != null else 0)
