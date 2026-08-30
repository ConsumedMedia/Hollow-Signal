extends SceneTree
## Setup and battle integration checks. No third-party test framework.

const ErrorMonitor = preload("res://tests/engine_error_monitor.gd")

const MENU: String = "res://scenes/main_menu.tscn"
const HUB: String = "res://scenes/hub.tscn"
const BATTLE: String = "res://scenes/battle_test.tscn"
const HELP: String = "res://scenes/help.tscn"

var _failures: int = 0
var _checks: int = 0
var _monitor: ErrorMonitor = ErrorMonitor.new()


func _initialize() -> void:
	OS.add_logger(_monitor)
	_run.call_deferred()


func _run() -> void:
	var test_store: SaveStore = SaveStore.new("user://hollow_signal_setup_test")
	test_store.delete_all()
	root.get_node("SaveService").set("store", test_store)
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("SETUP SMOKE: timed out before completion")
		quit(1))
	var version: Dictionary = Engine.get_version_info()
	_check(version.major == 4 and version.minor == 7 and version.patch == 2, "Pinned Godot 4.7.2")
	_check(not OS.has_feature("mono"), "Standard build, no .NET dependency")
	_check(ProjectSettings.get_setting("rendering/renderer/rendering_method") == "gl_compatibility", "Compatibility renderer configured")
	_check(root.content_scale_size == Vector2i(1920, 1080), "1920x1080 design resolution")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "Proportional scaling with letterboxing")
	for action: StringName in [&"ui_accept", &"ui_cancel", &"ui_focus_next", &"ui_up", &"ui_down", &"toggle_fullscreen"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Input binding: %s" % action)

	# Exercise each scene at both acceptance resolutions and a non-16:9 size.
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 900)]:
		root.size = window_size
		for scene_path: String in [MENU, HUB, BATTLE, HELP]:
			await _open(scene_path)
			_check_layout(scene_path, window_size)
			if "--capture" in OS.get_cmdline_user_args():
				await _capture(scene_path, window_size)

	test_store.delete_all()
	root.get_node("CampaignService").set("state", null)
	await _open(MENU)
	var new_game: Button = current_scene.get_node("%NewGame") as Button
	new_game.pressed.emit()
	new_game.pressed.emit()
	# A different same-frame request must also be ignored while replacing a scene.
	(current_scene.get_node("%BattleTest") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == HUB, "New Game opens hub once, despite duplicate input")
	(current_scene.get_node("%OpenBattleTest") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == BATTLE, "Hub opens battle test")
	(current_scene.get_node("%BackToHub") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == HUB, "Battle back button opens hub")
	(current_scene.get_node("%MainMenu") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == MENU, "Hub main menu button works")
	(current_scene.get_node("%BattleTest") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == BATTLE, "Menu opens battle test directly")
	(current_scene.get_node("%MainMenu") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == MENU, "Battle main menu button works")
	(current_scene.get_node("%Help") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == HELP and (current_scene.get_node("%Reference") as RichTextLabel).text.contains("POWER AND OVERCHARGE"), "Menu opens the spoiler-free mechanics reference")
	(current_scene.get_node("%Back") as Button).pressed.emit()
	await _settle()
	_check(current_scene.scene_file_path == MENU, "Help returns to the main menu")

	await _open(BATTLE)
	await _press_key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == HUB, "Escape returns battle to hub")
	await _press_key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == MENU, "Escape returns hub to menu")
	await _press_key(KEY_ESCAPE)
	_check(current_scene.scene_file_path == MENU, "Escape at menu does not quit")
	await _press_key(KEY_ENTER)
	_check(current_scene.scene_file_path == MENU and (current_scene.get_node("%NewGameConfirmation") as ConfirmationDialog).visible, "Enter activates New Game and requires replacement confirmation")
	(current_scene.get_node("%NewGameConfirmation") as ConfirmationDialog).confirmed.emit()
	await _settle()
	_check(current_scene.scene_file_path == HUB, "Confirmed keyboard New Game opens the hub")
	await _open(MENU)
	await _press_key(KEY_TAB)
	_check(root.gui_get_focus_owner() == current_scene.get_node("%LoadGame"), "Tab advances focus to available Load Campaign")
	await _press_key(KEY_TAB, true)
	_check(root.gui_get_focus_owner() == current_scene.get_node("%NewGame"), "Shift+Tab returns focus")
	await _press_key(KEY_DOWN)
	_check(root.gui_get_focus_owner() == current_scene.get_node("%LoadGame"), "Arrow key advances focus to available Load Campaign")
	await _start_new_game()
	_check(current_scene.scene_file_path == HUB, "Mouse input reaches New Game through the GUI")
	if DisplayServer.get_name() != "headless":
		await _press_key(KEY_F11)
		_check(root.mode == Window.MODE_EXCLUSIVE_FULLSCREEN, "F11 enters fullscreen")
		await _press_key(KEY_F11)
		_check(root.mode == Window.MODE_WINDOWED, "F11 returns to windowed mode")

	await _test_attack_button_clicks()
	await _test_battle_flow()
	await _test_class_battle_ui()
	await _test_manual_opening()
	await _test_drill_opening()
	await _test_vulnerability_ui()
	await _test_presentation_ui()
	await _test_campaign_ui()
	await _test_exploration_ui()
	await _test_save_ui()
	test_store.delete_all()
	_check(_monitor.error_count() == 0, "No engine errors during scene checks")
	# Optional negative self-test proves this runner exits unsuccessfully.
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_check(false, "Intentional failure to verify exit code")
	print("SETUP SMOKE: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_presentation_ui() -> void:
	root.size = Vector2i(1280, 720)
	await _open(BATTLE, false)
	var controller: BattleController = current_scene.get_node("BattleController") as BattleController
	controller.enemy_timer.wait_time = 0.4
	var stage: BattleStage = current_scene.get_node("Margin/Layout/Stage") as BattleStage
	var room_map: BattleRoomMap = current_scene.get_node("%BattleRoomMap") as BattleRoomMap
	_check(room_map != null and room_map.expedition == controller.state.expedition
		and room_map.displayed_room_id() == ContentCatalogue.SHIP.entry_id,
		"Combat HUD shows a read-only authored ship route and current position")
	_check("HP " in (current_scene.get_node("%SelectedActorSummary") as Label).text
		and "STRAIN " in (current_scene.get_node("%SelectedActorSummary") as Label).text,
		"Lower command deck summarizes the active combatant using existing Hollow Signal rules")
	var parallax_nodes: Array[Node] = stage.find_children("*", "Parallax2D", true, false)
	_check(parallax_nodes.size() == 3, "Battle example has distant, machinery and foreground Parallax2D layers")
	var repeat_ok: bool = true
	var scales: Array[Vector2] = []
	for node: Node in parallax_nodes:
		var layer: Parallax2D = node as Parallax2D
		repeat_ok = repeat_ok and is_equal_approx(layer.repeat_size.x, stage.size.x) and layer.repeat_times >= 3
		scales.append(layer.scroll_scale)
	_check(repeat_ok and Vector2(0.15, 0.15) in scales and Vector2(0.4, 0.4) in scales and Vector2(1.15, 1.15) in scales,
		"Battle parallax strips repeat at the viewport edge with the authored depth multipliers")
	var puppets: int = 0
	var puppets_inside_stage: bool = true
	for child: Node in stage.get_children():
		if child is CharacterPresentation:
			puppets += 1
			puppets_inside_stage = puppets_inside_stage and Rect2(Vector2.ZERO, stage.size).encloses(
				(child as CharacterPresentation).visual_rect_in_parent())
	_check(puppets == 8 and CharacterPresentation.POSES == [&"idle", &"walk", &"attack", &"support", &"hurt", &"downed", &"death"],
		"Reusable character presentation exposes all seven required states and stages both parties")
	_check(stage.size.y >= 220.0 and puppets_inside_stage,
		"All full character silhouettes fit inside the enlarged clipped battle theatre")
	var hud_rect: Rect2 = (current_scene.get_node("%TurnLabel") as Label).get_global_rect()
	stage.call("_impact_scroll")
	await process_frame
	_check((current_scene.get_node("%TurnLabel") as Label).get_global_rect() == hud_rect,
		"Battle camera/parallax motion leaves the scalable HUD fixed")

	await _await_player(controller)
	stage.animation_scale = 4.0
	var command: ActionCommand = _first_attack(controller.state)
	_check(command != null and controller.submit_player_action(command.action_id,
		command.target_ids[0] if not command.target_ids.is_empty() else &"", command.expected_turn, command.overcharge),
		"A legal action enters the presentation sequence after rules resolve")
	_check(controller.phase == BattleController.Phase.RESOLVING and stage.is_presenting()
		and not (current_scene.get_node("%SkipPresentation") as Button).disabled,
		"Actions remain locked and Skip Animation becomes available during presentation")
	await create_timer(0.12).timeout
	_check(stage.is_focused(), "Damaging actions temporarily focus the acting and targeted characters")
	if "--capture" in OS.get_cmdline_user_args():
		# At the deliberately slow test scale this lands during the impact popup.
		await create_timer(1.05).timeout
		await _capture(BATTLE, Vector2i(root.size), "m9_action_focus")
	(current_scene.get_node("%SkipPresentation") as Button).pressed.emit()
	await _settle()
	_check(not stage.is_presenting() and not stage.is_focused() and controller.phase != BattleController.Phase.RESOLVING,
		"Skipping presentation restores the full formation and acknowledges the resolved action without locking combat")

	var fallback_marker: Dictionary = {"finished": false}
	stage.presentation_finished.connect(func() -> void: fallback_marker.finished = true, CONNECT_ONE_SHOT)
	stage.play_missing_animation_for_test()
	await _settle()
	_check(fallback_marker.finished and not stage.is_presenting(),
		"Missing animation falls back immediately and completes its presentation sequence")

	var corridor := CorridorView.new()
	corridor.size = Vector2(960.0, 180.0)
	current_scene.add_child(corridor)
	await process_frame
	var corridor_layers: Array[Node] = corridor.find_children("*", "Parallax2D", true, false)
	var corridor_repeat_ok: bool = corridor_layers.size() == 3
	for node: Node in corridor_layers:
		var layer: Parallax2D = node as Parallax2D
		corridor_repeat_ok = corridor_repeat_ok and is_equal_approx(layer.repeat_size.x, corridor.size.x) and layer.repeat_times >= 3
	_check(corridor_repeat_ok, "Corridor uses three edge-matched repeating Parallax2D strips")
	corridor.begin(0.2)
	await create_timer(0.05).timeout
	var offsets_differ: bool = corridor_layers.size() == 3 \
		and not is_equal_approx((corridor_layers[0] as Parallax2D).scroll_offset.x, (corridor_layers[2] as Parallax2D).scroll_offset.x)
	corridor.finish()
	_check(offsets_differ and not corridor.visible, "Corridor layers move at different depths and skip uses the normal finish path")
	corridor.queue_free()


func _test_campaign_ui() -> void:
	root.size = Vector2i(1280, 720)
	await _open(MENU)
	await _start_new_game()
	var service: Node = root.get_node("CampaignService")
	var campaign: CampaignState = service.get("state") as CampaignState
	var roster: GridContainer = current_scene.get_node("%RosterGrid") as GridContainer
	_check(campaign != null and campaign.roster.size() == 8 and roster.get_child_count() == 8, "New Game creates eight visible persistent crew")
	_check(campaign.party_ids.size() == 4 and not (current_scene.get_node("%Deploy") as Button).disabled, "Four starting ranks are ready to deploy")
	var first: Button = roster.get_child(0) as Button
	await _click_button(first)
	var first_id: StringName = campaign.roster[0].id
	await _click_button(current_scene.get_node("%RankBack") as Button)
	_check(campaign.party_ids[1] == first_id, "Hub rank button changes deployment order")
	await _click_button(current_scene.get_node("%BuyModule") as Button)
	await _click_button(current_scene.get_node("%EquipModule") as Button)
	_check(campaign.owned_modules.size() == 1 and campaign.get_crew(first_id).module_id == campaign.owned_modules[0], "Hub purchase and equip controls assign one module")
	await _click_button(current_scene.get_node("%Deploy") as Button)
	_check(current_scene.scene_file_path == "res://scenes/expedition.tscn" and campaign.active_expedition != null, "Deploy opens an expedition owned by the campaign")
	await _click_button(current_scene.get_node("%EndTest") as Button)
	_check(current_scene.scene_file_path == HUB and campaign.active_expedition == null, "Guaranteed room retreat returns to the persistent hub")
	_check((current_scene.get_node("%Report") as Label).text.contains("Retreat"), "Hub reports the expedition outcome once")
	_check_layout(HUB, Vector2i(1280, 720))


func _test_save_ui() -> void:
	var service: Node = root.get_node("SaveService")
	var store: SaveStore = service.get("store") as SaveStore
	store.delete_all()
	root.get_node("CampaignService").set("state", null)
	await _open(MENU)
	await _start_new_game()
	var campaign: CampaignState = root.get_node("CampaignService").get("state") as CampaignState
	campaign.salvage = 41
	_check(service.call("save_campaign", campaign).ok, "Hub campaign checkpoint can be written through the application service")
	campaign.salvage = 999
	await _open(MENU)
	await _click_button(current_scene.get_node("%LoadGame") as Button)
	campaign = root.get_node("CampaignService").get("state") as CampaignState
	_check(current_scene.scene_file_path == HUB and campaign.salvage == 41, "Load Campaign replaces live state only with the validated checkpoint")
	var expedition: ExpeditionState = CampaignRules.deploy(campaign, 7000)
	ExpeditionRules.begin_travel(expedition, &"receiving")
	ExpeditionRules.arrive(expedition)
	var room: RoomDefinition = ExpeditionRules.begin_encounter(expedition)
	var expected_seed: int = expedition.rooms[room.id].encounter_seed
	var expected_health: int = expedition.crew[0].health
	_check(service.call("save_campaign", campaign).ok, "Battle entry checkpoint is written before combat state exists")
	expedition.crew[0].health = 1
	await _open(MENU)
	await _click_button(current_scene.get_node("%LoadGame") as Button)
	await _settle()
	campaign = root.get_node("CampaignService").get("state") as CampaignState
	var expedition_screen: Control = current_scene
	var resumed_battle: Control = expedition_screen.get("battle") as Control
	var resumed_controller: BattleController = resumed_battle.get_node("BattleController") as BattleController if resumed_battle != null else null
	_check(current_scene.scene_file_path == "res://scenes/expedition.tscn" and resumed_battle != null, "Loading a battle-entry checkpoint automatically restarts the encounter")
	_check(campaign.active_expedition.crew[0].health == expected_health and resumed_controller != null and resumed_controller.battle_seed == expected_seed, "Restarted encounter restores entry health and the same seed")
	var damaged: FileAccess = FileAccess.open(store.main_path, FileAccess.WRITE)
	damaged.store_string("{ damaged")
	damaged.close()
	await _open(MENU)
	_check((current_scene.get_node("%LoadGame") as Button).disabled and not (current_scene.get_node("%RecoverBackup") as Button).disabled, "Damaged main checkpoint disables Load and offers the known-good backup")
	await _click_button(current_scene.get_node("%RecoverBackup") as Button)
	_check(current_scene.scene_file_path in [HUB, "res://scenes/expedition.tscn"] and store.inspect().main.ok, "Backup recovery repairs the main slot and opens its validated campaign checkpoint")
	store.delete_all()
	var unsupported: Dictionary = SaveCodec.encode(CampaignRules.create_campaign())
	unsupported.version = 999
	var unsupported_file: FileAccess = FileAccess.open(store.main_path, FileAccess.WRITE)
	unsupported_file.store_string(JSON.stringify(unsupported))
	unsupported_file.close()
	await _open(MENU)
	_check((current_scene.get_node("%LoadGame") as Button).disabled and (current_scene.get_node("%SaveStatus") as Label).text.contains("unsupported"), "Unsupported save is reported and cannot be loaded or silently overwritten")


func _test_exploration_ui() -> void:
	var expedition_scene: String = "res://scenes/expedition.tscn"
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _open(expedition_scene, false)
		var state: ExpeditionState = current_scene.get("expedition") as ExpeditionState
		var map: RoomMap = current_scene.get_node("%RoomMap") as RoomMap
		_check(state.current_room == &"airlock" and map.buttons.size() == 8, "Exploration scene shows eight authored room buttons")
		_check(not map.buttons[&"receiving"].disabled and map.buttons[&"signal_core"].disabled, "Map only permits adjacent travel")
		_check_layout(expedition_scene, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(expedition_scene, window_size, "m6_airlock")
		await _click_button(map.buttons[&"receiving"])
		_check(state.power == 95 and state.destination == &"receiving", "GUI travel starts one corridor and spends five power")
		_check((current_scene.get_node("%Corridor") as CorridorView).visible, "Corridor presentation is visible while travelling")
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(expedition_scene, window_size, "m6_corridor")
		await _click_button(current_scene.get_node("%SkipCorridor") as Button)
		_check(state.current_room == &"receiving" and state.destination.is_empty(), "Skipping corridor completes arrival without extra power cost")
		_check((current_scene.get_node("%Engage") as Button).visible, "Entering combat room exposes the engage action")
		await _click_button(current_scene.get_node("%Engage") as Button)
		var battle_view: Control = current_scene.get("battle") as Control
		var controller: BattleController = battle_view.get_node("BattleController") as BattleController
		controller.enemy_timer.wait_time = 0.001
		_check(controller.expedition == state and controller.state.crew_ranks.size() == 4, "Embedded battle uses the same expedition object")
		_check((battle_view.get_node("%BattleRoomMap") as BattleRoomMap).displayed_room_id() == &"receiving",
			"Combat route marker follows the party into the current expedition room")
		_check(not (battle_view.get_node("%Restart") as Button).visible and not (battle_view.get_node("%NextBattle") as Button).visible, "Expedition combat hides fresh/reset test controls")
		_check((battle_view.get_node("%ReturnToRoom") as Button).disabled, "Cannot leave an unresolved expedition fight")
		for action: int in range(250):
			await _await_player(controller)
			if controller.state.outcome != &"ongoing":
				break
			var command: ActionCommand = EnemyPolicy.choose_action(controller.state)
			controller.submit_player_action(command.action_id, command.target_ids[0] if not command.target_ids.is_empty() else &"", command.expected_turn, command.overcharge)
			await _settle()
		_check(controller.state.outcome == &"victory", "Exploration's first patrol can be won through the existing controller")
		var wounded: int = state.crew[0].health
		var power: int = state.power
		await _click_button(battle_view.get_node("%ReturnToRoom") as Button)
		_check(current_scene.get("battle") == null and state.rooms[&"receiving"].resolved and state.power == power and state.crew[0].health == wounded, "Return to room preserves wounds/power and marks the encounter resolved")
		_check_layout(expedition_scene, window_size)

		# Controlled inventory fixture: full hold, then one-time authored salvage.
		state.current_room = &"salvage"
		state.rooms[&"salvage"].visited = true
		ExpeditionRules.inspect(state, &"accept")
		current_scene.call("_refresh")
		await _settle()
		_check(not state.pending_loot.is_empty() and (current_scene.get_node("%LootNotice") as Label).text.contains("HOLD FULL"), "Overflow displays a clear keep/discard decision")
		_check(map.buttons[&"hazard"].disabled, "Overflow disables travel")
		_check_layout(expedition_scene, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(expedition_scene, window_size, "m6_overflow")
		var grid: GridContainer = current_scene.get_node("%InventoryGrid") as GridContainer
		await _click_button(grid.get_child(0) as Button)
		await _click_button(current_scene.get_node("%DiscardSlot") as Button)
		var dialog: ConfirmationDialog = current_scene.get_node("DiscardConfirmation") as ConfirmationDialog
		_check(dialog.visible and dialog.dialog_text.contains("Discard ALL"), "Discarding a stored stack requires explicit confirmation")
		dialog.confirmed.emit()
		dialog.hide()
		await _settle()
		_check(state.inventory.stacks.size() <= 12, "Confirmed replacement never exceeds twelve slots")
		while not state.pending_loot.is_empty():
			ExpeditionRules.discard_pending(state)
		current_scene.call("_refresh")
		await _settle()
		_check(not map.buttons[&"hazard"].disabled, "Resolving overflow unlocks connected travel")
		# Normal corridor completion and skip share the same once-only arrival path.
		await _click_button(map.buttons[&"hazard"])
		await create_timer(state.ship.corridor_seconds + 0.1).timeout
		_check(state.current_room == &"hazard" and state.destination.is_empty(), "Unskipped corridor completes through the same arrival rule")
		_check_layout(expedition_scene, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(expedition_scene, window_size, "m6_hazard")


func _test_drill_opening() -> void:
	await _open(BATTLE, false)
	var controller: BattleController = current_scene.get_node("BattleController") as BattleController
	controller.enemy_timer.wait_time = 0.001
	await _click_button(current_scene.get_node("%Drill") as Button)
	await _click_button(current_scene.get_node("%Shot") as Button)
	await _click_button(_slot(ActorState.Team.CREW, 1))
	_check(controller.state.active_actor_id == &"crew_1", "README drill: revived C1 gets its unused turn naturally")
	await _click_button(current_scene.get_node("%Wait") as Button)
	_check(controller.state.active_actor_id == &"crew_2", "README drill: C2 follows C1")
	await _click_button(current_scene.get_node("%Wait") as Button)
	await _await_player(controller)
	_check(controller.state.active_actor_id == &"crew_3", "README drill: Ranger follows the enemy action")
	await _click_button(current_scene.get_node("%Strike") as Button)
	await _click_button(current_scene.get_node("%Overcharge") as Button)
	_check((current_scene.get_node("%SelectedDetail") as Label).text.contains("E4 6–9"), "README drill: Shaken Overcharge preview is 6–9")
	await _click_button(_slot(ActorState.Team.ENEMY, 4))
	_check(controller.expedition.power == 0, "README drill: charged target click spends the last 10 power")


func _test_vulnerability_ui() -> void:
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _open(BATTLE, false)
		var controller: BattleController = current_scene.get_node("BattleController") as BattleController
		controller.enemy_timer.wait_time = 10.0
		await _click_button(current_scene.get_node("%Drill") as Button)
		_check(controller.state.active_actor_id == &"crew_4" and controller.state.get_actor(&"crew_1").is_downed(), "Drill naturally starts with Medic and downed Breacher")
		_check(_slot(ActorState.Team.CREW, 1).text.contains("DOWNED") and _slot(ActorState.Team.CREW, 3).text.contains("SHAKEN"), "Downed and Shaken are readable labels, not color alone")
		_check((current_scene.get_node("%PowerLabel") as Label).text.contains("LOW") and controller.expedition.power == 10, "Drill shows low power pressure")
		await _click_button(current_scene.get_node("%Shot") as Button)
		var heal_target: Button = _slot(ActorState.Team.CREW, 1)
		_check(not heal_target.disabled and heal_target.text.contains("DOWNED"), "Field patch can select the downed ally")
		var charge: CheckButton = current_scene.get_node("%Overcharge") as CheckButton
		_check(charge.disabled and not charge.button_pressed, "Support abilities cannot enable Overcharge")
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m5_downed")
		await _click_button(heal_target)
		_check(controller.state.get_actor(&"crew_1").health == 8 and controller.expedition.get_crew(&"crew_1").health == 8, "GUI heal revives and updates the persistent crew record")
		_check(controller.state.get_actor(&"crew_4").uses.get(&"field_patch", 0) == 1, "Revival uses exactly one healing charge")

		_fixture_player_turn(controller, &"crew_3")
		controller.state_changed.emit()
		await _settle()
		# Select the Ranger's first ability through its real button.
		await _click_button(current_scene.get_node("%Strike") as Button)
		_check(not charge.disabled, "Damaging ability can enable Overcharge with exactly 10 power")
		var before_rng: int = controller.rng.state
		await _click_button(charge)
		_check(charge.button_pressed and controller.expedition.power == 10 and controller.rng.state == before_rng, "Selecting Overcharge changes neither power nor gameplay randomness")
		var target: ActorState = controller.state.get_actor(&"enemy_4")
		var ability: AbilityDefinition = controller.state.get_actor(&"crew_3").definition.abilities[0]
		var predicted: int = CombatRules.adjusted_damage(target, ability, ability.damage_min, controller.state.get_actor(&"crew_3"), true)
		_check((current_scene.get_node("%SelectedDetail") as Label).text.contains("E4 %d" % predicted), "Shaken and Overcharge are included in displayed target damage")
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m5_overcharge")
		var hp: int = target.health
		var original_state: CombatState = controller.state
		await _click_button(_slot(ActorState.Team.ENEMY, 4))
		_check(controller.expedition.power == 0 and target.health < hp, "GUI charged attack spends 10 power and deals damage")
		_check(not controller.submit_player_action(ability.id, target.id, 1, true), "Repeat/stale charged click is rejected")
		_fixture_player_turn(controller, &"crew_3")
		await _settle()
		_check(charge.disabled and not charge.button_pressed and original_state.outcome == &"ongoing", "Zero power disables Overcharge but does not end combat")

		# Maximum live card content, including all statuses and Shaken, fits both sizes.
		var crew: ActorState = controller.state.get_actor(&"crew_3")
		for status: StatusDefinition in [
			ContentCatalogue.BREACHER.abilities[1].effects[0].status,
			ContentCatalogue.TECHNICIAN.abilities[1].effects[0].status,
			ContentCatalogue.TECHNICIAN.abilities[0].effects[0].status]:
			crew.statuses.append(StatusState.new(status, crew))
		controller.state_changed.emit()
		await _settle()
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m5_statuses")
		await _click_button(current_scene.get_node("%Restart") as Button)
		_check(controller.expedition != original_state.expedition and controller.expedition.power == 100 and controller.battle_seed == 1729, "Fresh expedition leaves the drill and restores the original seed")
		_check(original_state.expedition.power == 0, "Fresh restart does not mutate the abandoned expedition")

	# Natural battle victory, next-room carryover, and repeat click guard.
	await _open(BATTLE, false)
	var controller: BattleController = current_scene.get_node("BattleController") as BattleController
	controller.enemy_timer.wait_time = 0.001
	controller.enemy_definitions = ContentCatalogue.enemy_party(true)
	current_scene.call("restart_battle")
	await _play_class_battle(controller, false)
	var previous: ExpeditionState = controller.expedition
	var survivors: Dictionary[StringName, Array] = {}
	for member: CrewState in previous.crew:
		survivors[member.id] = [member.health, member.strain, member.shaken, member.dead]
	var prior_power: int = previous.power
	var next_button: Button = current_scene.get_node("%NextBattle") as Button
	_check(not next_button.disabled and controller.state.outcome == &"victory", "Victory enables the next-battle control")
	next_button.pressed.emit()
	next_button.pressed.emit()
	await _settle()
	_check(controller.expedition == previous and previous.power == prior_power - 5, "Next battle carries the same expedition and duplicate clicks spend only one corridor cost")
	var preserved: bool = true
	for member: CrewState in previous.crew:
		preserved = preserved and survivors[member.id] == [member.health, member.strain, member.shaken, member.dead]
	_check(preserved, "Next battle preserves health, strain, Shaken and dead records at safe power")
	_check(controller.state.get_actor(&"crew_4").uses.is_empty(), "Next battle resets the Medic's per-battle healing uses")
	_check(next_button.disabled, "Next battle is unavailable while combat is active")
	await _play_class_battle(controller, true)
	_check(controller.expedition.failed and (current_scene.get_node("%PowerLabel") as Label).text.contains("DEAD:"), "Defeat visibly lists lost crew and marks the expedition failed")
	_check((current_scene.get_node("%NextBattle") as Button).disabled, "Defeated expedition cannot continue")
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _settle()
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m5_defeat")
	await _test_pacing_independence()


func _test_pacing_independence() -> void:
	var baseline: Array[Dictionary] = []
	var final_crew: Array[Dictionary] = []
	var final_power: int = 0
	for pace: float in [0.001, 0.025]:
		await _open(BATTLE, false)
		var controller: BattleController = current_scene.get_node("BattleController") as BattleController
		controller.enemy_timer.wait_time = pace
		var transcript: Array[Dictionary] = []
		controller.events_resolved.connect(func(events: Array[CombatEvent]) -> void:
			for event: CombatEvent in events:
				transcript.append({"kind": event.kind, "source": event.source_id, "target": event.target_id,
					"amount": event.amount, "hp": event.health_after, "strain": event.strain_after,
					"power": event.power_after, "ranks": event.rank_ids.duplicate(), "outcome": event.outcome}))
		for index: int in range(300):
			await _await_player(controller)
			if controller.state.outcome != &"ongoing":
				break
			var command: ActionCommand = EnemyPolicy.choose_action(controller.state)
			_check(controller.submit_player_action(command.action_id, command.target_ids[0] if not command.target_ids.is_empty() else &"", command.expected_turn, command.overcharge), "Pacing test accepts legal command")
			await _settle()
		var crew: Array[Dictionary] = []
		for member: CrewState in controller.expedition.crew:
			crew.append({"id": member.id, "hp": member.health, "strain": member.strain, "shaken": member.shaken, "dead": member.dead})
		_check(controller.state.outcome == &"victory", "Pacing test completes victory")
		if pace == 0.001:
			baseline = transcript
			final_crew = crew
			final_power = controller.expedition.power
		else:
			_check(transcript == baseline and crew == final_crew and final_power == controller.expedition.power, "Different presentation pacing yields identical ordered events, health, strain, deaths and power")


func _test_manual_opening() -> void:
	await _open(BATTLE, false)
	var controller: BattleController = current_scene.get_node("BattleController") as BattleController
	controller.enemy_timer.wait_time = 0.001
	# Exact beginner walkthrough: no state overrides or fabricated actor turns.
	var actors: Array[StringName] = [&"crew_3", &"crew_2", &"crew_1", &"crew_4"]
	var skills: Array[int] = [0, 0, 1, 1]
	var targets: Array[StringName] = [&"enemy_4", &"enemy_1", &"crew_4", &"crew_3"]
	for index: int in range(actors.size()):
		await _await_player(controller)
		_check(controller.state.active_actor_id == actors[index], "README opening reaches %s naturally" % actors[index])
		await _click_button(current_scene.get_node(["%Strike", "%Shot", "%Skill3"][skills[index]]) as Button)
		var target: ActorState = controller.state.get_actor(targets[index])
		var hp: int = target.health
		await _click_button(_slot(target.side, controller.state.get_rank(target.id)))
		if index == 0:
			_check(hp - target.health in range(6, 9), "README Covering shot damages the rear enemy")
		elif index == 1:
			_check(target.get_status(StatusDefinition.Kind.DAMAGE_OVER_TIME) != null and hp - target.health >= 4, "README Cutting beam applies Scorch")
		elif index == 2:
			_check(target.get_status(StatusDefinition.Kind.PROTECTION) != null, "README Brace protects the Medic")
		else:
			_check(target.health == target.definition.max_health and controller.state.get_actor(&"crew_4").uses[&"field_patch"] == 1,
				"README Field patch restores the injured Ranger and spends one use")



func _test_class_battle_ui() -> void:
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _open(BATTLE, false)
		var controller: BattleController = current_scene.get_node("BattleController") as BattleController
		_check(controller.state.get_actor(&"crew_1").definition == ContentCatalogue.BREACHER
			and controller.state.get_actor(&"crew_4").definition == ContentCatalogue.MEDIC, "Default battle contains the four different classes")
		_check((current_scene.get_node("%TurnLabel") as Label).text.contains("Ranger"), "Acting class is explicit in the turn header")
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m4_default")
		for crew_index: int in range(4):
			for skill_index: int in range(3):
				current_scene.call("restart_battle")
				controller.enemy_timer.wait_time = 10.0
				# Controlled fixture for button coverage; full-battle tests below use natural turns.
				var actor_id: StringName = StringName("crew_%d" % (crew_index + 1))
				var actor: ActorState = controller.state.get_actor(actor_id)
				for crew_id: StringName in controller.state.crew_ranks:
					var crew: ActorState = controller.state.get_actor(crew_id)
					crew.health -= 8
					crew.strain = 40
				_fixture_player_turn(controller, actor_id)
				await _settle()
				var ability: AbilityDefinition = actor.definition.abilities[skill_index]
				var button: Button = current_scene.get_node(["%Strike", "%Shot", "%Skill3"][skill_index]) as Button
				# Fallback is legal at the Ranger's initial rank 3; every class skill is usable in this fixture.
				_check(button.visible and not button.disabled and button.text.contains(ability.display_name), "Class button ready: %s" % ability.display_name)
				await _click_button(button)
				_check(current_scene.get("selected_action") == ability.id, "GUI selects class skill: %s" % ability.display_name)
				var command: ActionCommand = null
				for candidate: ActionCommand in CombatRules.get_legal_actions(controller.state, actor_id):
					if candidate.action_id == ability.id:
						command = candidate
						break
				_check(command != null, "Selected class skill has a legal target")
				if command == null:
					continue
				var target: ActorState = controller.state.get_actor(command.target_ids[0])
				var card: Button = _slot(target.side, controller.state.get_rank(target.id))
				_check(not card.disabled and card.text.contains("TARGET"), "Support and attack targets are labelled and clickable")
				_check_layout(BATTLE, window_size)
				if "--capture" in OS.get_cmdline_user_args():
					await _capture(BATTLE, window_size, "m4_" + String(ability.id))
				var before_turn: int = controller.state.turn_number
				await _click_button(card)
				_check(controller.state.turn_number == before_turn + 1 and actor.uses.get(ability.id, 0) == 1,
					"GUI resolves the class skill once: %s" % ability.display_name)
				if ability.id == &"field_patch":
					_fixture_player_turn(controller, actor_id)
					await _settle()
					_check(button.text.contains("1 left"), "Healing button displays the remaining battle use")
		# Maximum status/strain display uses isolated state, not modified Resources.
		current_scene.call("restart_battle")
		for actor: ActorState in controller.state.actors:
			actor.strain = 100
			for status: StatusDefinition in [ContentCatalogue.BREACHER.abilities[1].effects[0].status,
				ContentCatalogue.TECHNICIAN.abilities[1].effects[0].status, ContentCatalogue.TECHNICIAN.abilities[0].effects[0].status]:
				actor.statuses.append(StatusState.new(status, actor))
		controller.state_changed.emit()
		await _settle()
		_check_layout(BATTLE, window_size)
		_check(_slot(ActorState.Team.CREW, 1).text.contains("P2 X2 D2"), "All three status counters and maximum strain fit on the actor card")
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m4_statuses")
		await _click_button(current_scene.get_node("%Encounter") as Button)
		_check(controller.state.get_actor(&"enemy_3").definition == ContentCatalogue.CHORISTER
			and controller.state.get_actor(&"crew_4").uses.is_empty(), "Switching patrol introduces the strain enemy and resets battle state")
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "m4_signal_patrol")

	for patrol: bool in [false, true]:
		await _open(BATTLE, false)
		var controller: BattleController = current_scene.get_node("BattleController") as BattleController
		if patrol:
			await _click_button(current_scene.get_node("%Encounter") as Button)
		controller.enemy_timer.wait_time = 0.001
		await _play_class_battle(controller, false)
		_check(controller.state.outcome == &"victory", "Class party wins through UI commands against patrol %s" % patrol)
		await _check_outcome_layout("m4_victory_" + str(patrol))
		print("M4 UI VICTORY ", patrol, ": round ", controller.state.round_number, " / turns ", controller.state.turn_number)
		current_scene.call("restart_battle")
		await _play_class_battle(controller, true)
		_check(controller.state.outcome == &"defeat", "Waiting loses the class battle against patrol %s" % patrol)
		await _check_outcome_layout("m4_defeat_" + str(patrol))


func _fixture_player_turn(controller: BattleController, actor_id: StringName) -> void:
	controller.state.round_order.erase(actor_id)
	controller.state.round_order.push_front(actor_id)
	controller.state.turn_cursor = 0
	controller.state.active_actor_id = actor_id
	controller.call("_sync_phase")


func _play_class_battle(controller: BattleController, waits: bool) -> void:
	for index: int in range(300):
		await _await_player(controller)
		if controller.state.outcome != &"ongoing":
			return
		if waits:
			(current_scene.get_node("%Wait") as Button).pressed.emit()
		else:
			var command: ActionCommand = EnemyPolicy.choose_action(controller.state)
			if command.action_id == &"wait":
				(current_scene.get_node("%Wait") as Button).pressed.emit()
			else:
				current_scene.call("select_action", command.action_id)
				var target: ActorState = controller.state.get_actor(command.target_ids[0])
				_slot(target.side, controller.state.get_rank(target.id)).pressed.emit()
		await _settle()
	_check(false, "Class battle did not finish")



func _test_attack_button_clicks() -> void:
	# Exercise GUI hit testing and pressed connections, not direct select_action calls.
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _open(BATTLE)
		var controller: BattleController = current_scene.get_node("BattleController") as BattleController
		controller.enemy_timer.wait_time = 0.001
		var strike: Button = current_scene.get_node("%Strike") as Button
		var shot: Button = current_scene.get_node("%Shot") as Button
		var move: Button = current_scene.get_node("%Move") as Button
		var wait_button: Button = current_scene.get_node("%Wait") as Button
		_check(controller.state.active_actor_id == &"crew_3" and controller.state.get_rank(&"crew_3") == 3
			and strike.disabled and not shot.disabled, "Initial rear actor can shoot but cannot Close strike")
		await _click_button(strike)
		_check(current_scene.get("selected_action") == &"shot" and controller.state.turn_number == 0,
			"Clicking a disabled Close strike does not change selection or spend an action")
		await _click_button(wait_button)
		_check(controller.state.active_actor_id == &"crew_1" and controller.state.get_rank(&"crew_1") == 1
			and not strike.disabled and shot.disabled, "One GUI Wait reaches C1 at rank 1 and enables Close strike")
		await _click_button(move)
		_check(current_scene.get("selected_action") == &"move", "GUI Move click changes the selected ability")
		await _click_button(strike)
		_check(current_scene.get("selected_action") == &"strike" and controller.state.turn_number == 1,
			"GUI Close strike click selects the attack without spending the action")
		_check(not _slot(ActorState.Team.ENEMY, 1).disabled and not _slot(ActorState.Team.ENEMY, 2).disabled
			and _slot(ActorState.Team.ENEMY, 3).disabled and _slot(ActorState.Team.ENEMY, 4).disabled,
			"Selected Close strike enables only enemy ranks 1 and 2")
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, "battle_strike_selected")
		var target: ActorState = controller.state.actor_at(ActorState.Team.ENEMY, 1)
		var health_before: int = target.health
		await _click_button(_slot(ActorState.Team.ENEMY, 1))
		_check(health_before - target.health in range(6, 9) and controller.state.turn_number == 2,
			"Close strike GUI target click deals damage and spends exactly one action")

		await _click_button(current_scene.get_node("%Restart") as Button)
		await _click_button(move)
		await _click_button(_slot(ActorState.Team.CREW, 2))
		_check(controller.state.get_rank(&"crew_3") == 2 and controller.state.active_actor_id == &"crew_1",
			"Moving C3 forward ends C3's turn; the buttons now belong to C1")
		await _click_button(wait_button)
		_check(controller.state.active_actor_id == &"crew_2" and controller.state.get_rank(&"crew_2") == 3
			and strike.disabled and not shot.disabled, "Swapped-back C2 must shoot even while C3 is at the front")
		for attempt: int in range(16):
			await _await_player(controller)
			if controller.state.active_actor_id == &"crew_3":
				break
			await _click_button(wait_button)
		print("STRIKE AFTER MOVE: active=", controller.state.active_actor_id, " / rank=", controller.state.get_rank(&"crew_3"),
			" / crew=", controller.state.crew_ranks, " / disabled=", strike.disabled)
		_check(controller.state.active_actor_id == &"crew_3" and controller.state.get_rank(&"crew_3") in [1, 2]
			and not strike.disabled and shot.disabled, "Moved C3 can Close strike when its next turn arrives")
		await _click_button(move)
		await _click_button(strike)
		_check(current_scene.get("selected_action") == &"strike", "GUI Close strike remains selectable after moving forward")
		target = controller.state.actor_at(ActorState.Team.ENEMY, 1)
		health_before = target.health
		await _click_button(_slot(ActorState.Team.ENEMY, 1))
		_check(health_before - target.health in range(6, 9), "Moved actor's Close strike damages a target through GUI input")


func _test_battle_flow() -> void:
	root.size = Vector2i(1280, 720)
	await _open(BATTLE)
	var controller: BattleController = current_scene.get_node("BattleController") as BattleController
	controller.enemy_timer.wait_time = 0.01
	await _await_player(controller)
	var state: CombatState = controller.state
	print("M3 DEFAULT ORDER: ", state.round_order, " / ", state.initiative_scores)
	_check(state.actors.size() == 8 and state.crew_ranks.size() == 4 and state.enemy_ranks.size() == 4, "UI starts with four actors on each side")
	_check((current_scene.get_node("%TurnLabel") as Label).text.contains(state.get_actor(state.active_actor_id).short_name()), "Current actor identified in header")
	_check((current_scene.get_node("%OrderLabel") as Label).text.contains("Speed + d6"), "Initiative queue visible")
	_check((current_scene.get_node("%Wait") as Button).disabled == false, "Wait enabled on crew turns")
	_check(root.gui_get_focus_owner() == current_scene.get_node("%Shot"), "Initial keyboard focus selects the usable rear attack")
	var initial_rng: int = controller.rng.state
	var initial_order: Array[StringName] = state.round_order.duplicate()
	var attack_command: ActionCommand = _first_attack(state)
	var target: ActorState = state.get_actor(attack_command.target_ids[0])
	current_scene.call("select_action", attack_command.action_id)
	var target_button: Button = _slot(target.side, state.get_rank(target.id))
	_check(not target_button.disabled and target_button.text.contains("TARGET"), "Legal attack targets are clickable and labelled")
	var bad_target: Button = _slot(ActorState.Team.CREW, state.get_rank(state.active_actor_id))
	bad_target.pressed.emit()
	_check(state.turn_number == 0, "Illegal target signal cannot change battle state")
	# Repeated signals are stronger than clicks: even disabled buttons can emit.
	target_button.pressed.emit()
	var first_damage: int = 20 - target.health
	target_button.pressed.emit()
	(current_scene.get_node("%Wait") as Button).pressed.emit()
	_check(state.turn_number == 1 and controller.phase == BattleController.Phase.RESOLVING, "Same-frame input resolves one action even before another crew turn")
	_check((current_scene.get_node("%Strike") as Button).disabled and (current_scene.get_node("%Wait") as Button).disabled, "All actions lock while resolving")
	_check((current_scene.get_node("%Status") as Label).text.contains("%d damage" % first_damage), "Damage snapshot reaches combat log")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	await _settle()
	_check(controller.state.turn_number == 0 and controller.rng.state == initial_rng and controller.state.round_order == initial_order, "Restart cancels deferred resolution and repeats initiative")
	# Real GUI mouse input reaches an enemy card after selection.
	attack_command = _first_attack(controller.state)
	current_scene.call("select_action", attack_command.action_id)
	target = controller.state.get_actor(attack_command.target_ids[0])
	await _click_button(_slot(target.side, controller.state.get_rank(target.id)))
	_check(20 - target.health == first_damage, "GUI target click repeats the first damage roll after restart")
	await _await_player(controller)

	# Reach a boundary between front and rear without overriding rules.
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	for attempt: int in range(16):
		await _await_player(controller)
		if controller.state.get_rank(controller.state.active_actor_id) in [2, 3]:
			break
		(current_scene.get_node("%Wait") as Button).pressed.emit()
		await _settle()
	state = controller.state
	var mover: StringName = state.active_actor_id
	var from_rank: int = state.get_rank(mover)
	var to_rank: int = 3 if from_rank == 2 else 2
	var ally: ActorState = state.actor_at(ActorState.Team.CREW, to_rank)
	var order_before: Array[StringName] = state.round_order.duplicate()
	var turn_before: int = state.turn_number
	var before_strike: bool = CombatRules.ability_reason(state, mover, &"strike").is_empty()
	(current_scene.get_node("%Move") as Button).pressed.emit()
	_check(not _slot(ActorState.Team.CREW, to_rank).disabled and _slot(ActorState.Team.CREW, to_rank).text.contains("SWAP"), "Move highlights adjacent allies")
	_check(_slot(ActorState.Team.CREW, from_rank).disabled and _slot(ActorState.Team.ENEMY, 1).disabled, "Move disables self and opposing targets")
	await _check_outcome_layout("battle_move")
	_slot(ActorState.Team.CREW, to_rank).pressed.emit()
	await _settle()
	_check(state.get_rank(mover) == to_rank and state.get_rank(ally.id) == from_rank, "UI swap changes both ranks")
	_check(state.turn_number == turn_before + 1 and state.round_order == order_before, "UI swap consumes one turn and keeps the round queue")
	_check(CombatRules.ability_reason(state, mover, &"strike").is_empty() != before_strike, "Front/rear crossing immediately changes ability legality")
	_check((current_scene.get_node("%Status") as Label).text.contains("swaps rank"), "Move event explains action cost")
	await _await_player(controller)
	var rank: int = state.get_rank(state.active_actor_id)
	_check((current_scene.get_node("%Strike") as Button).disabled == (rank > 2) and (current_scene.get_node("%Shot") as Button).disabled == (rank <= 2), "Displayed skill availability follows the current rank")
	_check((current_scene.get_node("%ActionHelp") as Label).text.contains("Needs actor ranks"), "Disabled skill reason is visible without hovering")
	await _check_outcome_layout("battle_moved")

	# Restart while the timer for an enemy is pending.
	for attempt: int in range(16):
		if controller.phase == BattleController.Phase.ENEMY_TURN:
			break
		controller.enemy_timer.wait_time = 0.4
		(current_scene.get_node("%Wait") as Button).pressed.emit()
		await _settle()
	_check(controller.phase == BattleController.Phase.ENEMY_TURN, "Enemy phase reached automatically from the initiative queue")
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	await create_timer(0.5).timeout
	_check(controller.state.turn_number == 0 and controller.state.get_actor(&"crew_1").health == 30, "Restart cancels the previous battle's pending enemy action")
	controller.enemy_timer.wait_time = 0.001
	for attempt: int in range(12):
		await _await_player(controller)
		if controller.state.enemy_ranks.size() < 4:
			break
		var command: ActionCommand = _first_attack(controller.state)
		current_scene.call("select_action", command.action_id)
		var enemy: ActorState = controller.state.get_actor(command.target_ids[0])
		_slot(enemy.side, controller.state.get_rank(enemy.id)).pressed.emit()
		await _settle()
	_check(controller.state.get_actor(&"enemy_1") == null and _slot(ActorState.Team.ENEMY, 1).text.contains("E2") and _slot(ActorState.Team.ENEMY, 4).text.contains("EMPTY"), "First enemy removal updates visible rank labels and empties the rear slot")
	await _check_outcome_layout("battle_compacted")
	await _play_to_outcome(controller, false)
	_check(controller.state.outcome == &"victory", "Four-position battle can be won through UI targets")
	_check((current_scene.get_node("%TurnLabel") as Label).text.contains("VICTORY") and (current_scene.get_node("%Wait") as Button).disabled, "Victory visible and input terminal")
	var terminal_turn: int = controller.state.turn_number
	(current_scene.get_node("%Wait") as Button).pressed.emit()
	_check(controller.state.turn_number == terminal_turn, "Post-victory input has no effect")
	await _check_outcome_layout("battle_victory")
	print("M3 VICTORY: round ", controller.state.round_number, " / turns ", controller.state.turn_number)
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	await _play_to_outcome(controller, true)
	_check(controller.state.outcome == &"defeat" and controller.state.crew_ranks.is_empty(), "Waiting can lose the full party battle")
	_check((current_scene.get_node("%TurnLabel") as Label).text.contains("DEFEAT") and (current_scene.get_node("%Move") as Button).disabled, "Defeat visible and input terminal")
	await _check_outcome_layout("battle_defeat")
	print("M3 DEFEAT: round ", controller.state.round_number, " / turns ", controller.state.turn_number)
	(current_scene.get_node("%Restart") as Button).pressed.emit()
	_check(controller.state.actors.size() == 8 and controller.state.outcome == &"ongoing", "Restart restores all eight actors after defeat")
	for attempt: int in range(16):
		if controller.phase == BattleController.Phase.ENEMY_TURN:
			break
		controller.enemy_timer.wait_time = 0.4
		(current_scene.get_node("%Wait") as Button).pressed.emit()
		await _settle()
	(current_scene.get_node("%BackToHub") as Button).pressed.emit()
	await _settle()
	await create_timer(0.5).timeout
	_check(current_scene.scene_file_path == HUB, "Leaving during enemy response safely frees the battle")


func _slot(team: ActorState.Team, rank: int) -> Button:
	var prefix: String = "Crew" if team == ActorState.Team.CREW else "Enemy"
	return current_scene.get_node("%%%sRank%d" % [prefix, rank]) as Button


func _first_attack(state: CombatState) -> ActionCommand:
	for command: ActionCommand in CombatRules.get_legal_actions(state, state.active_actor_id):
		if command.action_id not in [&"move", &"wait"]:
			return command
	return null


func _await_player(controller: BattleController) -> void:
	for attempt: int in range(500):
		if controller.phase in [BattleController.Phase.PLAYER_INPUT, BattleController.Phase.FINISHED]:
			return
		await create_timer(0.01).timeout
	_check(false, "Enemy/resolution timeout")


func _play_to_outcome(controller: BattleController, waits: bool) -> void:
	for action: int in range(200):
		await _await_player(controller)
		if controller.state.outcome != &"ongoing":
			return
		if waits:
			(current_scene.get_node("%Wait") as Button).pressed.emit()
		else:
			var command: ActionCommand = _first_attack(controller.state)
			if command == null:
				(current_scene.get_node("%Wait") as Button).pressed.emit()
			else:
				current_scene.call("select_action", command.action_id)
				var target: ActorState = controller.state.get_actor(command.target_ids[0])
				_slot(target.side, controller.state.get_rank(target.id)).pressed.emit()
		await _settle()
	_check(false, "Battle did not reach a terminal outcome")


func _check_outcome_layout(artifact_name: String) -> void:
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = window_size
		await _settle()
		_check_layout(BATTLE, window_size)
		if "--capture" in OS.get_cmdline_user_args():
			await _capture(BATTLE, window_size, artifact_name)


func _open(scene_path: String, legacy_fixture: bool = true) -> void:
	var result: Error = change_scene_to_file(scene_path)
	_check(result == OK, "Load %s" % scene_path)
	await _settle()
	if scene_path == BATTLE:
		(current_scene.get_node("Margin/Layout/Stage") as BattleStage).animation_scale = 0.01
	if scene_path == BATTLE and legacy_fixture:
		# Preserve M3 regressions against their original two-skill content.
		var controller: BattleController = current_scene.get_node("BattleController") as BattleController
		controller.crew_definitions = [ContentCatalogue.TEST_CREW, ContentCatalogue.TEST_CREW, ContentCatalogue.TEST_CREW, ContentCatalogue.TEST_CREW]
		controller.enemy_definitions = [ContentCatalogue.TEST_ENEMY, ContentCatalogue.TEST_ENEMY, ContentCatalogue.TEST_ENEMY, ContentCatalogue.TEST_ENEMY]
		current_scene.call("restart_battle")
		await _settle()


func _settle() -> void:
	for frame: int in range(4):
		await process_frame


func _press_key(keycode: Key, shift: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	Input.parse_input_event(event)
	await _settle()
	event = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.shift_pressed = shift
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _click_button(button: Button) -> void:
	var centre: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = centre
	root.push_input(motion, true)
	# Keep the synthetic gesture together. Yielding between down/up lets the
	# rendered window re-evaluate hover using the unrelated desktop cursor.
	# Both events still pass through Godot's GUI hit testing and button signals.
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.position = centre
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.pressed = pressed
		root.push_input(click, true)
	await _settle()


func _start_new_game() -> void:
	await _click_button(current_scene.get_node("%NewGame") as Button)
	if current_scene != null and current_scene.scene_file_path == MENU:
		var dialog: ConfirmationDialog = current_scene.get_node("%NewGameConfirmation") as ConfirmationDialog
		_check(dialog.visible, "Existing campaign requires New Game confirmation")
		dialog.confirmed.emit()
		await _settle()


func _capture(scene_path: String, window_size: Vector2i, artifact_name: String = "") -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "Screenshots require a graphical rendering run, not --headless")
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var basename: String = scene_path.get_file().get_basename() if artifact_name.is_empty() else artifact_name
	var filename: String = "res://.artifacts/%s_%dx%d.png" % [basename, window_size.x, window_size.y]
	# Viewport images exclude the black bars added by the Window. At 1280x900
	# the 16:9 game content is still 1280x720, centred in the taller window.
	var fit: float = minf(window_size.x / 1920.0, window_size.y / 1080.0)
	var content_size: Vector2i = Vector2i(Vector2(1920, 1080) * fit)
	_check(root.size == window_size, "Window has requested dimensions: %s" % window_size)
	_check(screenshot.get_size() == content_size, "Rendered content is %s inside %s" % [content_size, window_size])
	_check(screenshot.save_png(filename) == OK, "Saved rendered screenshot: %s" % filename)


func _check_layout(scene_path: String, window_size: Vector2i) -> void:
	var viewport_rect: Rect2 = root.get_visible_rect().grow(1.0)
	var layout_ok: bool = true
	for node: Node in current_scene.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		var ancestor: Node = control.get_parent()
		var inside_scroll: bool = false
		while ancestor != null and ancestor != current_scene:
			if ancestor is ScrollContainer:
				inside_scroll = true
				break
			ancestor = ancestor.get_parent()
		if inside_scroll:
			continue
		if not viewport_rect.encloses(control.get_global_rect()):
			layout_ok = false
			printerr("Outside viewport: %s %s" % [control.get_path(), control.get_global_rect()])
		if control is Label or control is Button:
			var minimum: Vector2 = control.get_combined_minimum_size()
			if control.size.x + 1.0 < minimum.x or control.size.y + 1.0 < minimum.y:
				layout_ok = false
				printerr("Text below minimum size: %s" % control.get_path())
	_check(layout_ok, "Controls fit: %s at %s" % [scene_path, window_size])
	var focused: Control = root.gui_get_focus_owner()
	_check(focused is Button and current_scene.is_ancestor_of(focused), "Keyboard focus ready: %s" % scene_path)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		printerr("FAIL: ", description)
