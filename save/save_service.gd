extends Node
## Persistent application service. Scenes request checkpoints; SaveStore owns files.

var store: SaveStore = SaveStore.new()


func inspect_saves() -> Dictionary:
	return store.inspect()


func save_campaign(campaign: CampaignState, allow_replace_invalid: bool = false) -> Dictionary:
	return store.save_campaign(campaign, allow_replace_invalid)


func load_campaign(use_backup: bool = false) -> Dictionary:
	return store.load_campaign(use_backup)
