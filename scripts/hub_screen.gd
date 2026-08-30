extends "res://scripts/screen_navigation.gd"
## Campaign preparation UI. CampaignRules owns every roster/currency mutation.

var campaign: CampaignState
var selected_crew: StringName = &""
var roster_buttons: Array[Button] = []
@onready var roster_grid: GridContainer = %RosterGrid
@onready var module_choice: OptionButton = %ModuleChoice
@onready var recruit_choice: OptionButton = %RecruitChoice

func _ready() -> void:
	super._ready()
	campaign = CampaignService.ensure_campaign()
	for definition: ActorDefinition in ContentCatalogue.crew_party():
		recruit_choice.add_item(definition.display_name)
		recruit_choice.set_item_metadata(recruit_choice.item_count - 1, definition.id)
	for module: ModuleDefinition in ContentCatalogue.MODULES:
		module_choice.add_item(module.display_name)
		module_choice.set_item_metadata(module_choice.item_count - 1, module.id)
	module_choice.item_selected.connect(func(_index: int) -> void: _refresh())
	(%ToggleParty as Button).pressed.connect(_toggle_party)
	(%RankForward as Button).pressed.connect(_move_rank.bind(-1))
	(%RankBack as Button).pressed.connect(_move_rank.bind(1))
	(%RestoreHealth as Button).pressed.connect(_restore_health)
	(%RecoverStrain as Button).pressed.connect(_recover_strain)
	(%Recruit as Button).pressed.connect(_recruit)
	(%BuyCell as Button).pressed.connect(_buy_cell)
	(%BuyModule as Button).pressed.connect(_buy_module)
	(%EquipModule as Button).pressed.connect(_equip_module)
	(%BuyUpgrade as Button).pressed.connect(_buy_upgrade)
	(%Deploy as Button).pressed.connect(_deploy)
	_refresh()
	_checkpoint()

func _select_crew(crew_id: StringName) -> void:
	selected_crew = crew_id
	_refresh()

func _toggle_party() -> void:
	if CampaignRules.toggle_party(campaign, selected_crew): _changed()

func _move_rank(direction: int) -> void:
	if CampaignRules.move_party(campaign, selected_crew, direction): _changed()

func _restore_health() -> void:
	if CampaignRules.restore_health_free(campaign, selected_crew): _changed()

func _recover_strain() -> void:
	if CampaignRules.recover_strain(campaign, selected_crew): _changed()

func _recruit() -> void:
	var member: CrewState = CampaignRules.recruit_free(campaign, _class_definition(recruit_choice.get_selected_metadata()))
	if member != null:
		selected_crew = member.id
		_changed()

func _buy_cell() -> void:
	if CampaignRules.buy_cell(campaign): _changed()

func _buy_module() -> void:
	if CampaignRules.buy_module(campaign, module_choice.get_selected_metadata()): _changed()

func _equip_module() -> void:
	if CampaignRules.equip_module(campaign, selected_crew, module_choice.get_selected_metadata()): _changed()

func _buy_upgrade() -> void:
	if CampaignRules.buy_upgrade(campaign): _changed()

func _deploy() -> void:
	if CampaignRules.deploy(campaign) != null:
		if _checkpoint(): open_screen("res://scenes/expedition.tscn")


func _changed() -> void:
	_refresh()
	_checkpoint()


func _checkpoint() -> bool:
	var result: Dictionary = SaveService.save_campaign(campaign)
	if not result.ok:
		campaign.last_report = "AUTOSAVE FAILED / " + result.message
		(%Report as Label).text = campaign.last_report
	return result.ok

func _refresh() -> void:
	for button: Button in roster_buttons: button.queue_free()
	roster_buttons.clear()
	for member: CrewState in campaign.roster:
		var button: Button = Button.new()
		var party_index: int = campaign.party_ids.find(member.id)
		var equipped: ModuleDefinition = member.module()
		button.text = "%s  /  %s%s\n%d/%d HP   %d strain%s\n%s" % [member.call_sign, member.definition.display_name,
			" / RANK %d" % (party_index + 1) if party_index >= 0 else "", member.health, member.max_health(), member.strain,
			" SHAKEN" if member.shaken else "", "DEAD" if member.dead else (equipped.display_name if equipped != null else "No module")]
		button.disabled = member.dead
		button.modulate = Color("77d5d9") if member.id == selected_crew else Color.WHITE
		button.pressed.connect(_select_crew.bind(member.id))
		roster_grid.add_child(button)
		roster_buttons.append(button)
	var selected: CrewState = campaign.get_crew(selected_crew)
	var available: bool = selected != null and not selected.dead
	(%ToggleParty as Button).disabled = not available
	(%ToggleParty as Button).text = "Remove from party" if available and selected.id in campaign.party_ids else "Add to party"
	(%RankForward as Button).disabled = not available or campaign.party_ids.find(selected.id) <= 0
	(%RankBack as Button).disabled = not available or campaign.party_ids.find(selected.id) < 0 or campaign.party_ids.find(selected.id) >= campaign.party_ids.size() - 1
	(%RestoreHealth as Button).disabled = not available or selected.health >= selected.max_health()
	(%RecoverStrain as Button).disabled = not available or selected.strain == 0 or campaign.salvage < CampaignRules.BALANCE.recovery_cost
	(%RecoverStrain as Button).text = "Treat %d strain / %d salvage" % [CampaignRules.BALANCE.recovery_amount, CampaignRules.BALANCE.recovery_cost]
	(%EquipModule as Button).disabled = not available or module_choice.get_selected_metadata() not in campaign.owned_modules
	(%BuyModule as Button).disabled = module_choice.get_selected_metadata() in campaign.owned_modules or campaign.salvage < CampaignRules.BALANCE.module_cost
	(%BuyCell as Button).disabled = campaign.salvage < CampaignRules.BALANCE.cell_cost
	(%BuyCell as Button).text = "Buy expedition power cell / %d salvage" % CampaignRules.BALANCE.cell_cost
	(%BuyUpgrade as Button).disabled = campaign.upgrade_tier >= 1 or campaign.salvage < CampaignRules.BALANCE.upgrade_cost
	(%BuyUpgrade as Button).text = "Crew plating upgrade +%d max HP / %d salvage" % [CampaignRules.BALANCE.upgrade_health_bonus, CampaignRules.BALANCE.upgrade_cost]
	(%BuyModule as Button).text = "Collect / %d salvage" % CampaignRules.BALANCE.module_cost
	(%Deploy as Button).disabled = campaign.party_ids.size() != 4
	(%Summary as Label).text = "SALVAGE %d   /   DATA %d   /   SUPPLY CELLS %d   /   UPGRADE %d/1   /   PARTY %d/4" % [campaign.salvage, campaign.data_wafers, campaign.starting_cells, campaign.upgrade_tier, campaign.party_ids.size()]
	(%Report as Label).text = campaign.last_report + "  Health restoration and basic recruitment are free; strain care costs %d salvage." % CampaignRules.BALANCE.recovery_cost
	var shown_module: ModuleDefinition = ContentCatalogue.get_module(module_choice.get_selected_metadata())
	(%ModuleLabel as Label).text = "MODULE / %s%s" % [shown_module.description, " / OWNED" if shown_module.id in campaign.owned_modules else ""]
	module_choice.tooltip_text = shown_module.description

func _class_definition(id: StringName) -> ActorDefinition:
	for definition: ActorDefinition in ContentCatalogue.crew_party():
		if definition.id == id: return definition
	return null
