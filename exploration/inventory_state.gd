class_name InventoryState
extends RefCounted
var capacity: int = 12
var stacks: Array[ItemStack] = []

func add(item: ItemDefinition, quantity: int) -> int:
	# Return overflow; never discard it or mutate the authored item.
	if item == null or not item.is_valid() or quantity < 0:
		return quantity
	var remaining: int = quantity
	for stack: ItemStack in stacks:
		if stack.definition.id == item.id:
			var accepted: int = mini(remaining, item.max_stack - stack.quantity)
			stack.quantity += accepted
			remaining -= accepted
	while remaining > 0 and stacks.size() < capacity:
		var accepted: int = mini(remaining, item.max_stack)
		stacks.append(ItemStack.new(item, accepted))
		remaining -= accepted
	return remaining
