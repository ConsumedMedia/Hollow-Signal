class_name ActionCommand
extends RefCounted
## A request, not a result. A turn token rejects stale/duplicate requests.

var actor_id: StringName
var action_id: StringName
var target_ids: Array[StringName]
var expected_turn: int


func _init(source: StringName, action: StringName, targets: Array[StringName], turn: int) -> void:
	actor_id = source
	action_id = action
	target_ids = targets.duplicate()
	expected_turn = turn
