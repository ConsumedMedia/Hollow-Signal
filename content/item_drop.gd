class_name ItemDrop
extends Resource
@export var item: ItemDefinition
@export var quantity: int = 1

func is_valid() -> bool:
	return item != null and item.is_valid() and quantity > 0
