class_name SaveCodec
extends RefCounted
## Converts mutable game records to validated, versioned data. Never serializes nodes.

const VERSION: int = 1


static func encode(campaign: CampaignState) -> Dictionary:
	var crew_data: Array[Dictionary] = []
	for member: CrewState in campaign.roster:
		crew_data.append({
			"id": String(member.id), "class_id": String(member.definition.id), "call_sign": member.call_sign,
			"health": member.health, "strain": member.strain, "shaken": member.shaken, "dead": member.dead,
			"module_id": String(member.module_id), "upgrade_health_bonus": member.upgrade_health_bonus})
	return {"version": VERSION, "campaign": {
		"roster": crew_data, "party_ids": _names(campaign.party_ids), "salvage": campaign.salvage,
		"data_wafers": campaign.data_wafers, "owned_modules": _names(campaign.owned_modules),
		"upgrade_tier": campaign.upgrade_tier, "starting_cells": campaign.starting_cells,
		"next_recruit_id": campaign.next_recruit_id, "expedition_number": campaign.expedition_number,
		"last_report": campaign.last_report, "active_expedition": _encode_expedition(campaign.active_expedition)}}


static func decode(document: Variant) -> Dictionary:
	if typeof(document) != TYPE_DICTIONARY:
		return _error("Save root is not an object.")
	var root: Dictionary = document
	if not root.has("version") or not _is_int(root.version):
		return _error("Save version is missing.")
	if int(root.version) != VERSION:
		return {"ok": false, "code": &"unsupported", "message": "Save version %s is unsupported; this file was not changed." % str(root.version)}
	if typeof(root.get("campaign")) != TYPE_DICTIONARY:
		return _error("Campaign data is missing.")
	var data: Dictionary = root.campaign
	var required: PackedStringArray = ["roster", "party_ids", "salvage", "data_wafers", "owned_modules", "upgrade_tier", "starting_cells", "next_recruit_id", "expedition_number", "last_report", "active_expedition"]
	for key: String in required:
		if not data.has(key):
			return _error("Campaign field '%s' is missing." % key)
	if typeof(data.roster) != TYPE_ARRAY or data.roster.is_empty() or data.roster.size() > 100:
		return _error("Roster is invalid.")
	var campaign: CampaignState = CampaignState.new()
	var ids: Array[StringName] = []
	var equipped: Array[StringName] = []
	for entry: Variant in data.roster:
		var decoded: Dictionary = _decode_crew(entry)
		if not decoded.ok:
			return decoded
		var member: CrewState = decoded.value
		if member.id in ids or (not member.module_id.is_empty() and member.module_id in equipped):
			return _error("Crew IDs and equipped modules must be unique.")
		ids.append(member.id)
		if not member.module_id.is_empty(): equipped.append(member.module_id)
		campaign.roster.append(member)
	var scalars: Dictionary = _campaign_scalars(data)
	if not scalars.ok:
		return scalars
	campaign.salvage = int(data.salvage)
	campaign.data_wafers = int(data.data_wafers)
	campaign.upgrade_tier = int(data.upgrade_tier)
	campaign.starting_cells = int(data.starting_cells)
	campaign.next_recruit_id = int(data.next_recruit_id)
	campaign.expedition_number = int(data.expedition_number)
	campaign.last_report = data.last_report
	var expected_upgrade_bonus: int = CampaignRules.BALANCE.upgrade_health_bonus if campaign.upgrade_tier == 1 else 0
	for member: CrewState in campaign.roster:
		if member.upgrade_health_bonus != expected_upgrade_bonus:
			return _error("Crew upgrade values do not match the campaign tier.")
	var owned_result: Dictionary = _decode_names(data.owned_modules, true)
	if not owned_result.ok: return owned_result
	campaign.owned_modules = owned_result.value
	for module_id: StringName in equipped:
		if module_id not in campaign.owned_modules:
			return _error("Equipped module is not owned.")
	var party_result: Dictionary = _decode_names(data.party_ids, false)
	if not party_result.ok: return party_result
	campaign.party_ids = party_result.value
	if campaign.party_ids.size() > CombatRules.MAX_RANKS:
		return _error("Party is too large.")
	for id: StringName in campaign.party_ids:
		var member: CrewState = campaign.get_crew(id)
		if member == null or member.dead:
			return _error("Party references missing or dead crew.")
	if data.active_expedition != null:
		var expedition_result: Dictionary = _decode_expedition(data.active_expedition, campaign)
		if not expedition_result.ok: return expedition_result
		campaign.active_expedition = expedition_result.value
	return {"ok": true, "code": &"ok", "message": "Campaign validated.", "state": campaign}


static func _encode_expedition(state: ExpeditionState) -> Variant:
	if state == null: return null
	var room_data: Dictionary = {}
	for id: StringName in state.rooms:
		var room: RoomState = state.rooms[id]
		room_data[String(id)] = {"visited": room.visited, "resolved": room.resolved, "encounter_seed": str(room.encounter_seed)}
	return {"crew_ids": _crew_ids(state.crew), "crew_ranks": _names(state.crew_ranks), "power": state.power,
		"failed": state.failed, "ship_id": "research_vessel", "rooms": room_data,
		"current_room": String(state.current_room), "destination": String(state.destination),
		"encounter_room": String(state.encounter_room), "inventory_capacity": state.inventory.capacity,
		"inventory": _encode_stacks(state.inventory.stacks), "pending_loot": _encode_stacks(state.pending_loot),
		"boss_cleared": state.boss_cleared, "outcome": String(state.outcome)}


static func _decode_expedition(value: Variant, campaign: CampaignState) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _error("Expedition is invalid.")
	var data: Dictionary = value
	var required: PackedStringArray = ["crew_ids", "crew_ranks", "power", "failed", "ship_id", "rooms", "current_room", "destination", "encounter_room", "inventory_capacity", "inventory", "pending_loot", "boss_cleared", "outcome"]
	for key: String in required:
		if not data.has(key): return _error("Expedition field '%s' is missing." % key)
	if not _is_int(data.power) or data.power < 0 or data.power > CombatRules.BALANCE.power_max or data.ship_id != "research_vessel" or not _is_int(data.inventory_capacity) or data.inventory_capacity != ContentCatalogue.SHIP.inventory_slots:
		return _error("Expedition balance data is invalid.")
	if typeof(data.failed) != TYPE_BOOL or typeof(data.boss_cleared) != TYPE_BOOL or typeof(data.current_room) != TYPE_STRING or typeof(data.destination) != TYPE_STRING or typeof(data.encounter_room) != TYPE_STRING or typeof(data.outcome) != TYPE_STRING:
		return _error("Expedition flags or locations are invalid.")
	var crew_ids: Dictionary = _decode_names(data.crew_ids, false)
	var ranks: Dictionary = _decode_names(data.crew_ranks, false)
	if not crew_ids.ok or not ranks.ok or crew_ids.value.size() != 4 or ranks.value.size() != 4:
		return _error("Expedition crew formation is invalid.")
	var state: ExpeditionState = ExpeditionState.new()
	for id: StringName in crew_ids.value:
		var member: CrewState = campaign.get_crew(id)
		if member == null: return _error("Expedition references missing crew.")
		state.crew.append(member)
	for id: StringName in ranks.value:
		if id not in crew_ids.value: return _error("Expedition rank references missing crew.")
	state.crew_ranks = ranks.value
	state.power = int(data.power)
	state.failed = data.failed
	state.battle_active = false
	state.ship = ContentCatalogue.SHIP
	if typeof(data.rooms) != TYPE_DICTIONARY or data.rooms.size() != state.ship.rooms.size(): return _error("Room state count is invalid.")
	for room: RoomDefinition in state.ship.rooms:
		if not data.rooms.has(String(room.id)) or typeof(data.rooms[String(room.id)]) != TYPE_DICTIONARY: return _error("Room state is missing.")
		var saved: Dictionary = data.rooms[String(room.id)]
		if typeof(saved.get("visited")) != TYPE_BOOL or typeof(saved.get("resolved")) != TYPE_BOOL: return _error("Room flags are invalid.")
		var seed: Dictionary = _decode_seed(saved.get("encounter_seed"))
		if not seed.ok: return seed
		var record: RoomState = RoomState.new()
		record.visited = saved.visited
		record.resolved = saved.resolved
		record.encounter_seed = seed.value
		state.rooms[room.id] = record
	state.current_room = StringName(data.current_room)
	state.destination = StringName(data.destination)
	state.encounter_room = StringName(data.encounter_room)
	if state.ship.get_room(state.current_room) == null or (not state.destination.is_empty() and state.ship.get_room(state.destination) == null) or (not state.encounter_room.is_empty() and state.encounter_room != state.current_room):
		return _error("Expedition location is invalid.")
	if not state.destination.is_empty() and state.destination not in state.ship.get_room(state.current_room).links:
		return _error("Corridor destination is not connected.")
	if not state.encounter_room.is_empty():
		var encounter: RoomDefinition = state.ship.get_room(state.encounter_room)
		if state.rooms[state.encounter_room].resolved or encounter.kind not in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS]:
			return _error("Battle checkpoint does not reference an unresolved encounter.")
	state.inventory = InventoryState.new()
	state.inventory.capacity = int(data.inventory_capacity)
	var inventory: Dictionary = _decode_stacks(data.inventory, state.inventory.capacity)
	# Pending loot is an unresolved quantity, not an inventory stack. An authored
	# cache may exceed max_stack until settle_loot() distributes or discards it.
	var pending: Dictionary = _decode_stacks(data.pending_loot, 64, true)
	if not inventory.ok: return inventory
	if not pending.ok: return pending
	state.inventory.stacks = inventory.value
	state.pending_loot = pending.value
	state.boss_cleared = data.boss_cleared
	state.outcome = StringName(data.outcome)
	if state.outcome not in [&"ongoing", &"success", &"retreat", &"defeat"]: return _error("Expedition outcome is invalid.")
	return {"ok": true, "value": state}


static func _decode_crew(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return _error("Crew entry is invalid.")
	var d: Dictionary = value
	for key: String in ["id", "class_id", "call_sign", "health", "strain", "shaken", "dead", "module_id", "upgrade_health_bonus"]:
		if not d.has(key): return _error("Crew field '%s' is missing." % key)
	var definition: ActorDefinition = ContentCatalogue.get_actor(StringName(d.class_id)) if typeof(d.class_id) == TYPE_STRING else null
	if definition == null or typeof(d.id) != TYPE_STRING or d.id.is_empty() or typeof(d.call_sign) != TYPE_STRING or d.call_sign.is_empty() or typeof(d.module_id) != TYPE_STRING:
		return _error("Crew identity is invalid.")
	if typeof(d.shaken) != TYPE_BOOL or typeof(d.dead) != TYPE_BOOL:
		return _error("Crew condition flags are invalid.")
	if not _is_int(d.health) or not _is_int(d.strain) or not _is_int(d.upgrade_health_bonus):
		return _error("Crew numeric values are invalid.")
	var member: CrewState = CrewState.new(StringName(d.id), definition)
	member.call_sign = d.call_sign
	member.health = int(d.health)
	member.strain = int(d.strain)
	member.shaken = d.shaken
	member.dead = d.dead
	member.module_id = StringName(d.module_id)
	member.upgrade_health_bonus = int(d.upgrade_health_bonus)
	if member.strain < 0 or member.strain > 100 or member.upgrade_health_bonus < 0:
		return _error("Crew values are invalid.")
	if not member.module_id.is_empty() and ContentCatalogue.get_module(member.module_id) == null: return _error("Crew module is unknown.")
	if member.health < 0 or member.health > member.max_health() or member.dead and member.health != 0 or member.shaken and member.strain < CombatRules.BALANCE.shaken_clear_below or member.strain == CombatRules.BALANCE.strain_max and not member.shaken:
		return _error("Crew health, death, or strain state is invalid.")
	return {"ok": true, "value": member}


static func _campaign_scalars(d: Dictionary) -> Dictionary:
	for key: String in ["salvage", "data_wafers", "upgrade_tier", "starting_cells", "next_recruit_id", "expedition_number"]:
		if not _is_int(d[key]) or d[key] < 0: return _error("Campaign number '%s' is invalid." % key)
	if d.upgrade_tier > 1 or typeof(d.last_report) != TYPE_STRING: return _error("Campaign upgrade or report is invalid.")
	return {"ok": true}


static func _decode_names(value: Variant, modules: bool) -> Dictionary:
	if typeof(value) != TYPE_ARRAY: return _error("ID list is invalid.")
	var result: Array[StringName] = []
	for raw: Variant in value:
		if typeof(raw) != TYPE_STRING or raw.is_empty(): return _error("ID is invalid.")
		var id: StringName = StringName(raw)
		if id in result or modules and ContentCatalogue.get_module(id) == null: return _error("ID list contains a duplicate or unknown value.")
		result.append(id)
	return {"ok": true, "value": result}


static func _encode_stacks(stacks: Array[ItemStack]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stack: ItemStack in stacks: result.append({"item_id": String(stack.definition.id), "quantity": stack.quantity})
	return result


static func _decode_stacks(value: Variant, capacity: int, allow_pending_quantity: bool = false) -> Dictionary:
	if typeof(value) != TYPE_ARRAY or value.size() > capacity: return _error("Cargo count is invalid.")
	var result: Array[ItemStack] = []
	for raw: Variant in value:
		if typeof(raw) != TYPE_DICTIONARY: return _error("Cargo entry is invalid.")
		var item_id: Variant = raw.get("item_id")
		if typeof(item_id) != TYPE_STRING: return _error("Cargo item ID is invalid.")
		var item: ItemDefinition = ContentCatalogue.get_item(StringName(item_id))
		var quantity: Variant = raw.get("quantity")
		if item == null or not _is_int(quantity): return _error("Cargo item or quantity is invalid.")
		var maximum: int = 1_000_000 if allow_pending_quantity else item.max_stack
		if quantity <= 0 or quantity > maximum: return _error("Cargo item or quantity is invalid.")
		result.append(ItemStack.new(item, int(quantity)))
	return {"ok": true, "value": result}


static func _decode_seed(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_STRING or not value.is_valid_int(): return _error("Random seed is invalid.")
	return {"ok": true, "value": int(value)}


static func _names(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values: result.append(String(value))
	return result


static func _crew_ids(values: Array[CrewState]) -> Array[String]:
	var result: Array[String] = []
	for value: CrewState in values: result.append(String(value.id))
	return result


static func _is_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value))


static func _error(message: String) -> Dictionary:
	return {"ok": false, "code": &"corrupt", "message": message}
