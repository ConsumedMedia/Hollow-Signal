class_name ItemDefinition
extends Resource
## Authored item values. Quantities live in ItemStack.
@export var id: StringName
@export var display_name: String
@export var max_stack: int = 1
@export var power_restored: int = 0

func is_valid() -> bool:
	return not id.is_empty() and not display_name.is_empty() and max_stack > 0 and power_restored >= 0
