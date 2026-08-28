class_name StatusDefinition
extends Resource
## Shared authored status. Duration is measured in the recipient's turn starts.

enum Kind { PROTECTION, EXPOSE, DAMAGE_OVER_TIME }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.EXPOSE
@export_range(1, 10) var duration: int = 2
@export_range(0, 100) var magnitude: int = 0


func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and duration > 0 \
		and kind in [Kind.PROTECTION, Kind.EXPOSE, Kind.DAMAGE_OVER_TIME] \
		and magnitude >= 0 and magnitude <= 100 \
		and (kind != Kind.DAMAGE_OVER_TIME or magnitude > 0)
