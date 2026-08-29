class_name CampaignRules
extends RefCounted
## Hub and expedition-return mutations only. No scene or audio dependency.

const BALANCE: CampaignBalance = preload("res://content/campaign_balance.tres")


static func create_campaign() -> CampaignState:
	var state: CampaignState = CampaignState.new()
	state.salvage = BALANCE.starting_salvage
	state.starting_cells = BALANCE.starting_cells
	var classes: Array[ActorDefinition] = ContentCatalogue.crew_party()
	var call_signs: PackedStringArray = ["Vela", "Kite", "Rook", "Morrow", "Sable", "Patch", "Orison", "Vale"]
	for copy: int in range(2):
		for definition: ActorDefinition in classes:
			var member: CrewState = CrewState.new(StringName("crew_%d" % (state.roster.size() + 1)), definition)
			member.call_sign = call_signs[state.roster.size()]
			state.roster.append(member)
	for index: int in range(4):
		state.party_ids.append(state.roster[index].id)
	return state


static func toggle_party(state: CampaignState, crew_id: StringName) -> bool:
	if state == null or state.active_expedition != null:
		return false
	var member: CrewState = state.get_crew(crew_id)
	if member == null or member.dead:
		return false
	if crew_id in state.party_ids:
		state.party_ids.erase(crew_id)
		return true
	if state.party_ids.size() >= CombatRules.MAX_RANKS:
		return false
	state.party_ids.append(crew_id)
	return true


static func move_party(state: CampaignState, crew_id: StringName, direction: int) -> bool:
	if state == null or state.active_expedition != null or crew_id not in state.party_ids:
		return false
	var index: int = state.party_ids.find(crew_id)
	var destination: int = index + signi(direction)
	if destination < 0 or destination >= state.party_ids.size():
		return false
	var other: StringName = state.party_ids[destination]
	state.party_ids[destination] = crew_id
	state.party_ids[index] = other
	return true


static func deploy(state: CampaignState, seed_value: int = 1729) -> ExpeditionState:
	if state == null or state.active_expedition != null or state.party_ids.size() != CombatRules.MAX_RANKS:
		return null
	var crew: Array[CrewState] = []
	for crew_id: StringName in state.party_ids:
		var member: CrewState = state.get_crew(crew_id)
		if member == null or member.dead:
			return null
		crew.append(member)
	state.expedition_number += 1
	state.active_expedition = ExpeditionRules.create_for_crew(ContentCatalogue.SHIP, crew,
		seed_value + state.expedition_number * 100, state.starting_cells)
	if state.active_expedition != null:
		state.starting_cells = 0
	return state.active_expedition


static func complete_expedition(state: CampaignState, outcome: StringName) -> bool:
	if state == null or state.active_expedition == null or outcome not in [&"success", &"retreat", &"defeat"]:
		return false
	var expedition: ExpeditionState = state.active_expedition
	if outcome == &"success" and (not expedition.boss_cleared or expedition.failed):
		return false
	if outcome == &"defeat" and not expedition.failed:
		return false
	if outcome == &"retreat" and expedition.failed:
		return false
	var scrap: int = _cargo_quantity(expedition, &"scrap")
	var wafers: int = _cargo_quantity(expedition, &"wafer")
	if outcome == &"retreat":
		scrap /= BALANCE.retreat_reward_divisor
		wafers /= BALANCE.retreat_reward_divisor
	elif outcome == &"defeat":
		scrap = 0
		wafers = 0
	state.salvage += scrap
	state.data_wafers += wafers
	state.last_report = "%s: recovered %d salvage and %d data." % [String(outcome).capitalize(), scrap, wafers]
	state.active_expedition = null
	state.party_ids = state.party_ids.filter(func(id: StringName) -> bool:
		var member: CrewState = state.get_crew(id)
		return member != null and not member.dead)
	return true


static func restore_health_free(state: CampaignState, crew_id: StringName) -> bool:
	var member: CrewState = state.get_crew(crew_id) if state != null else null
	if member == null or member.dead:
		return false
	member.health = member.max_health()
	return true


static func recover_strain(state: CampaignState, crew_id: StringName) -> bool:
	var member: CrewState = state.get_crew(crew_id) if state != null else null
	if member == null or member.dead or member.strain == 0 or state.salvage < BALANCE.recovery_cost:
		return false
	state.salvage -= BALANCE.recovery_cost
	member.strain = maxi(0, member.strain - BALANCE.recovery_amount)
	member.shaken = CombatRules.shaken_after(member.strain, member.shaken)
	return true


static func recruit_free(state: CampaignState, definition: ActorDefinition) -> CrewState:
	if state == null or definition == null or state.active_expedition != null:
		return null
	var member: CrewState = CrewState.new(StringName("crew_%d" % state.next_recruit_id), definition)
	member.call_sign = "Recruit %d" % state.next_recruit_id
	member.upgrade_health_bonus = BALANCE.upgrade_health_bonus if state.upgrade_tier >= 1 else 0
	state.next_recruit_id += 1
	state.roster.append(member)
	return member


static func buy_cell(state: CampaignState) -> bool:
	if state == null or state.active_expedition != null or state.salvage < BALANCE.cell_cost:
		return false
	state.salvage -= BALANCE.cell_cost
	state.starting_cells += 1
	return true


static func buy_module(state: CampaignState, module_id: StringName) -> bool:
	if state == null or state.active_expedition != null or module_id in state.owned_modules or state.salvage < BALANCE.module_cost:
		return false
	if ContentCatalogue.get_module(module_id) == null:
		return false
	state.salvage -= BALANCE.module_cost
	state.owned_modules.append(module_id)
	return true


static func equip_module(state: CampaignState, crew_id: StringName, module_id: StringName) -> bool:
	var member: CrewState = state.get_crew(crew_id) if state != null else null
	if member == null or member.dead or module_id not in state.owned_modules:
		return false
	for other: CrewState in state.roster:
		if other.module_id == module_id:
			other.module_id = &""
			other.health = mini(other.health, other.max_health())
	member.module_id = module_id
	member.health = mini(member.health, member.max_health())
	return true


static func buy_upgrade(state: CampaignState) -> bool:
	if state == null or state.active_expedition != null or state.upgrade_tier >= 1 or state.salvage < BALANCE.upgrade_cost:
		return false
	state.salvage -= BALANCE.upgrade_cost
	state.upgrade_tier = 1
	for member: CrewState in state.roster:
		member.upgrade_health_bonus = BALANCE.upgrade_health_bonus
	return true


static func _cargo_quantity(expedition: ExpeditionState, item_id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in expedition.inventory.stacks:
		if stack.definition.id == item_id:
			total += stack.quantity
	return total
