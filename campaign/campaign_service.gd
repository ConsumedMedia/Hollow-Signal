extends Node
## One in-memory campaign slot. Versioned disk persistence arrives in milestone 8.

var state: CampaignState


func new_campaign() -> CampaignState:
	state = CampaignRules.create_campaign()
	return state


func ensure_campaign() -> CampaignState:
	if state == null:
		return new_campaign()
	return state
