class_name ExpeditionRules
extends RefCounted
## Room, inventory and travel mutations only. No scene, timer or drawing dependency.

static func create(ship: ShipDefinition, crew: Array[ActorDefinition], seed_value: int = 1729) -> ExpeditionState:
	if ship == null or not ship.is_valid() or crew.is_empty() or crew.size() > CombatRules.MAX_RANKS:
		return null
	for actor: ActorDefinition in crew:
		if actor == null or not actor.is_valid():
			return null
	var state: ExpeditionState = CombatRules.new_expedition(crew)
	state.ship = ship
	state.inventory = InventoryState.new()
	state.inventory.capacity = ship.inventory_slots
	for index: int in range(ship.rooms.size()):
		var room: RoomDefinition = ship.rooms[index]
		var record: RoomState = RoomState.new()
		record.encounter_seed = seed_value + index
		state.rooms[room.id] = record
	state.current_room = ship.entry_id
	state.rooms[ship.entry_id].visited = true
	state.rooms[ship.entry_id].resolved = true
	_queue_loot(state, ship.starting_items)
	return state


static func can_interact(state: ExpeditionState) -> bool:
	return state != null and state.ship != null and not state.failed and not state.battle_active and state.encounter_room.is_empty() and state.destination.is_empty()


static func travel_reason(state: ExpeditionState, target: StringName) -> String:
	if not can_interact(state):
		return "Travel is locked during a corridor, battle or failed expedition."
	if not state.pending_loot.is_empty():
		return "Choose which cargo to keep or discard first."
	if not state.rooms[state.current_room].resolved:
		return "Resolve this room's encounter or inspection choice first."
	if target not in state.ship.get_room(state.current_room).links:
		return "Choose a connected room."
	return ""


static func begin_travel(state: ExpeditionState, target: StringName) -> bool:
	if not travel_reason(state, target).is_empty():
		return false
	state.power = maxi(0, state.power - CombatRules.BALANCE.corridor_power_cost)
	state.destination = target
	return true


static func arrive(state: ExpeditionState) -> bool:
	if state == null or state.destination.is_empty() or state.battle_active or state.failed:
		return false
	state.current_room = state.destination
	state.destination = &""
	state.rooms[state.current_room].visited = true
	_change_strain(state, CombatRules.room_strain(state.power))
	return true


static func inspect(state: ExpeditionState, choice: StringName) -> bool:
	if not can_interact(state) or not state.pending_loot.is_empty():
		return false
	var record: RoomState = state.rooms[state.current_room]
	var room: RoomDefinition = state.ship.get_room(state.current_room)
	if record.resolved or room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS, RoomDefinition.Kind.ENTRY]:
		return false
	if choice not in [&"accept", &"leave"]:
		return false
	record.resolved = true
	if choice == &"leave":
		return true
	if room.kind == RoomDefinition.Kind.HAZARD:
		_change_strain(state, room.strain_cost)
	elif room.kind == RoomDefinition.Kind.SAFE:
		for member: CrewState in state.crew:
			if not member.dead:
				member.health = mini(member.definition.max_health, member.health + room.recovery_health)
		_change_strain(state, -room.recovery_strain)
	_queue_loot(state, room.loot)
	return true


static func begin_encounter(state: ExpeditionState) -> RoomDefinition:
	if not can_interact(state) or not state.pending_loot.is_empty():
		return null
	var room: RoomDefinition = state.ship.get_room(state.current_room)
	if state.rooms[room.id].resolved or room.kind not in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS]:
		return null
	state.encounter_room = room.id
	return room


static func finish_encounter(state: ExpeditionState, battle: CombatState) -> bool:
	if state == null or battle == null or battle.expedition != state or battle.outcome == &"ongoing" or state.encounter_room.is_empty():
		return false
	if state.encounter_room != state.current_room or battle.encounter_room != state.encounter_room:
		return false
	var room: RoomDefinition = state.ship.get_room(state.encounter_room)
	state.encounter_room = &""
	if battle.outcome == &"defeat":
		return true
	if state.rooms[room.id].resolved:
		return false
	state.rooms[room.id].resolved = true
	if room.id == state.ship.boss_id:
		state.boss_cleared = true
	_queue_loot(state, room.loot)
	return true


static func use_power_cell(state: ExpeditionState, slot: int) -> bool:
	if not can_interact(state) or slot < 0 or slot >= state.inventory.stacks.size():
		return false
	var stack: ItemStack = state.inventory.stacks[slot]
	if stack.definition.power_restored <= 0 or state.power >= CombatRules.BALANCE.power_max:
		return false
	state.power = mini(CombatRules.BALANCE.power_max, state.power + stack.definition.power_restored)
	stack.quantity -= 1
	if stack.quantity == 0:
		state.inventory.stacks.remove_at(slot)
	settle_loot(state)
	return true


static func discard_pending(state: ExpeditionState) -> bool:
	if not can_interact(state) or state.pending_loot.is_empty():
		return false
	state.pending_loot.remove_at(0)
	settle_loot(state)
	return true


static func discard_slot(state: ExpeditionState, slot: int) -> bool:
	if not can_interact(state) or slot < 0 or slot >= state.inventory.stacks.size():
		return false
	state.inventory.stacks.remove_at(slot)
	settle_loot(state)
	return true


static func settle_loot(state: ExpeditionState) -> void:
	# Fill compatible partial stacks before asking about the remaining cargo.
	while not state.pending_loot.is_empty():
		var stack: ItemStack = state.pending_loot[0]
		stack.quantity = state.inventory.add(stack.definition, stack.quantity)
		if stack.quantity > 0:
			return
		state.pending_loot.remove_at(0)


static func _queue_loot(state: ExpeditionState, drops: Array[ItemDrop]) -> void:
	for drop: ItemDrop in drops:
		state.pending_loot.append(ItemStack.new(drop.item, drop.quantity))
	settle_loot(state)


static func _change_strain(state: ExpeditionState, amount: int) -> void:
	for member: CrewState in state.crew:
		if not member.dead:
			member.strain = clampi(member.strain + amount, 0, CombatRules.BALANCE.strain_max)
			member.shaken = CombatRules.shaken_after(member.strain, member.shaken)
