extends "res://scripts/screen_navigation.gd"
## Main-menu checkpoint controls. Live state changes only after a save validates.

@onready var new_game_dialog: ConfirmationDialog = %NewGameConfirmation


func _ready() -> void:
	super._ready()
	(%NewGame as Button).pressed.connect(_request_new_game)
	(%LoadGame as Button).pressed.connect(_load.bind(false))
	(%RecoverBackup as Button).pressed.connect(_load.bind(true))
	new_game_dialog.confirmed.connect(_start_new_game)
	_refresh_save_status()


func _request_new_game() -> void:
	var saves: Dictionary = SaveService.inspect_saves()
	if saves.main.code != &"missing" or saves.backup.code != &"missing":
		new_game_dialog.popup_centered(Vector2i(720, 240))
	else:
		_start_new_game()


func _start_new_game() -> void:
	var campaign: CampaignState = CampaignRules.create_campaign()
	var result: Dictionary = SaveService.save_campaign(campaign, true)
	if not result.ok:
		(%SaveStatus as Label).text = "NEW GAME NOT STARTED / " + result.message
		return
	CampaignService.state = campaign
	open_screen("res://scenes/hub.tscn")


func _load(use_backup: bool) -> void:
	var result: Dictionary = SaveService.load_campaign(use_backup)
	if not result.ok:
		(%SaveStatus as Label).text = "LOAD FAILED / " + result.message
		_refresh_save_status(false)
		return
	if use_backup:
		var repair: Dictionary = SaveService.save_campaign(result.state, true)
		if not repair.ok:
			(%SaveStatus as Label).text = "RECOVERY FAILED / " + repair.message
			return
	CampaignService.state = result.state
	open_screen("res://scenes/expedition.tscn" if result.state.active_expedition != null else "res://scenes/hub.tscn")


func _refresh_save_status(replace_message: bool = true) -> void:
	var saves: Dictionary = SaveService.inspect_saves()
	(%LoadGame as Button).disabled = not saves.main.ok
	(%RecoverBackup as Button).disabled = not saves.backup.ok
	(%RecoverBackup as Button).visible = saves.backup.code != &"missing"
	if not replace_message: return
	var message: String = "AUTOSAVE / " + saves.main.message
	if saves.main.code == &"unsupported": message += " It will not be overwritten without confirmed New Game."
	if saves.backup.ok: message += "  Known-good backup available."
	elif saves.backup.code != &"missing": message += "  Backup: " + saves.backup.message
	(%SaveStatus as Label).text = message
