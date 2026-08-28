class_name ItemStack
extends RefCounted
var definition: ItemDefinition
var quantity: int

func _init(item: ItemDefinition, count: int) -> void:
	definition = item
	quantity = count
