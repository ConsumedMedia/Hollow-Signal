class_name ShipDefinition
extends Resource
@export var entry_id: StringName
@export var boss_id: StringName
@export var rooms: Array[RoomDefinition] = []
@export var starting_items: Array[ItemDrop] = []
@export var inventory_slots: int = 12
@export var corridor_seconds: float = 1.2

func get_room(room_id: StringName) -> RoomDefinition:
	for room: RoomDefinition in rooms:
		if room != null and room.id == room_id:
			return room
	return null

func is_valid() -> bool:
	if rooms.size() != 8 or inventory_slots != 12 or corridor_seconds <= 0.0:
		return false
	var ids: Array[StringName] = []
	for room: RoomDefinition in rooms:
		if room == null or room.id.is_empty() or room.id in ids or room.links.is_empty():
			return false
		ids.append(room.id)
		if room.strain_cost < 0 or room.recovery_health < 0 or room.recovery_strain < 0:
			return false
		if room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS] and (room.enemies.is_empty() or room.enemies.size() > 4):
			return false
		for actor: ActorDefinition in room.enemies:
			if actor == null or not actor.is_valid():
				return false
		for drop: ItemDrop in room.loot:
			if drop == null or not drop.is_valid():
				return false
	if get_room(entry_id) == null or get_room(boss_id) == null:
		return false
	for room: RoomDefinition in rooms:
		var links_seen: Array[StringName] = []
		for neighbor: StringName in room.links:
			if neighbor == room.id or neighbor in links_seen or get_room(neighbor) == null or room.id not in get_room(neighbor).links:
				return false
			links_seen.append(neighbor)
	for drop: ItemDrop in starting_items:
		if drop == null or not drop.is_valid():
			return false
	var reached: Array[StringName] = [entry_id]
	var cursor: int = 0
	while cursor < reached.size():
		for neighbor: StringName in get_room(reached[cursor]).links:
			if neighbor not in reached:
				reached.append(neighbor)
		cursor += 1
	return reached.size() == rooms.size()
