class_name ExpeditionState
extends RefCounted
## M5's minimal runtime carrier, not a room graph, campaign or save service.

var crew: Array[CrewState] = []
var crew_ranks: Array[StringName] = []
var power: int = 0 # Initialized from balance by CombatRules.new_expedition.
var failed: bool = false
var battle_active: bool = false
var ship: ShipDefinition
var rooms: Dictionary[StringName, RoomState] = {}
var current_room: StringName = &""
var destination: StringName = &""
var encounter_room: StringName = &""
var inventory: InventoryState
var pending_loot: Array[ItemStack] = []
var boss_cleared: bool = false
var outcome: StringName = &"ongoing"


func get_crew(crew_id: StringName) -> CrewState:
	for member: CrewState in crew:
		if member.id == crew_id:
			return member
	return null
