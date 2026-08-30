class_name CampaignState
extends RefCounted
## Mutable campaign data. SaveCodec serializes values and authored content IDs only.

var roster: Array[CrewState] = []
var party_ids: Array[StringName] = []
var salvage: int = 0
var data_wafers: int = 0
var owned_modules: Array[StringName] = []
var upgrade_tier: int = 0
var starting_cells: int = 0
var next_recruit_id: int = 9
var expedition_number: int = 0
var active_expedition: ExpeditionState
var last_report: String = "Select four crew and arrange their ranks."


func get_crew(crew_id: StringName) -> CrewState:
	for member: CrewState in roster:
		if member.id == crew_id:
			return member
	return null
