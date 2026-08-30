extends Node
## One live campaign slot. SaveService validates disk data before assigning state.

var state: CampaignState


func new_campaign() -> CampaignState:
	state = CampaignRules.create_campaign()
	return state


func ensure_campaign() -> CampaignState:
	if state == null:
		return new_campaign()
	return state
