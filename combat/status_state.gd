class_name StatusState
extends RefCounted
## Duration and source belong to this instance, never to the shared Resource.

var definition: StatusDefinition
var remaining: int
var source_id: StringName
var source_name: String


func _init(authored: StatusDefinition, source: ActorState) -> void:
	definition = authored
	remaining = authored.duration
	source_id = source.id
	source_name = source.short_name()
