extends "res://scripts/screen_navigation.gd"
## Expedition owns runtime state; a temporary battle child borrows that state.
const BATTLE_SCENE: PackedScene = preload("res://scenes/battle_test.tscn")
@export var expedition_seed: int = 1729
var expedition: ExpeditionState
var battle: Control
var selected_slot: int = -1
var _discard_choice: int = -3
var _last_action_frame: int = -1
@onready var room_map: RoomMap = %RoomMap
@onready var corridor: CorridorView = %Corridor
@onready var inventory_grid: GridContainer = %InventoryGrid
@onready var dialog: ConfirmationDialog = $DiscardConfirmation
var inventory_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	expedition = ExpeditionRules.create(ContentCatalogue.SHIP, ContentCatalogue.crew_party(), expedition_seed)
	if expedition == null:
		(%RoomDescription as Label).text = "Invalid ship content. Check content/ship.tres and its room Resources."
		return
	for slot: int in range(expedition.inventory.capacity):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 58)
		button.add_theme_font_size_override("font_size", 18)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("203343")
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 6.0
		style.content_margin_bottom = 6.0
		for style_name: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			button.add_theme_stylebox_override(style_name, style)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_slot.bind(slot))
		inventory_grid.add_child(button)
		inventory_buttons.append(button)
	room_map.configure(expedition)
	room_map.room_selected.connect(_travel)
	corridor.finished.connect(_arrive)
	(%SkipCorridor as Button).pressed.connect(corridor.finish)

	(%InspectAccept as Button).pressed.connect(_inspect.bind(&"accept"))
	(%InspectLeave as Button).pressed.connect(_inspect.bind(&"leave"))
	(%Engage as Button).pressed.connect(_engage)
	(%UseCell as Button).pressed.connect(_use_cell)
	(%DiscardSlot as Button).pressed.connect(_ask_discard_slot)
	(%DiscardIncoming as Button).pressed.connect(_ask_discard_incoming)
	(%EndTest as Button).pressed.connect(open_screen.bind("res://scenes/hub.tscn"))
	dialog.confirmed.connect(_confirm_discard)
	dialog.canceled.connect(func() -> void: _discard_choice = -3)
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if battle != null or (expedition != null and (not expedition.destination.is_empty() or not expedition.pending_loot.is_empty())):
		if event.is_action_pressed("toggle_fullscreen"):
			super._unhandled_key_input(event)
		return
	super._unhandled_key_input(event)


func _accept_input() -> bool:
	if _last_action_frame == Engine.get_process_frames():
		return false
	_last_action_frame = Engine.get_process_frames()
	return true


func _travel(room_id: StringName) -> void:
	if not _accept_input() or not ExpeditionRules.begin_travel(expedition, room_id):
		return
	selected_slot = -1
	_refresh()
	corridor.crew_count = expedition.crew_ranks.size()
	corridor.begin(expedition.ship.corridor_seconds)


func _arrive() -> void:
	if ExpeditionRules.arrive(expedition):
		_refresh()
		# The focused map/skip control was hidden during travel. Focus the room's action.
		for button: Button in [%Engage, %InspectAccept, %EndTest]:
			if button.is_visible_in_tree() and not button.disabled:
				button.grab_focus()
				break


func _inspect(choice: StringName) -> void:
	if _accept_input() and ExpeditionRules.inspect(expedition, choice):
		_refresh()


func _select_slot(slot: int) -> void:
	selected_slot = slot
	_refresh()


func _use_cell() -> void:
	if _accept_input() and ExpeditionRules.use_power_cell(expedition, selected_slot):
		selected_slot = -1
		_refresh()


func _ask_discard_slot() -> void:
	if not ExpeditionRules.can_interact(expedition) or selected_slot < 0 or selected_slot >= expedition.inventory.stacks.size():
		return
	var stack: ItemStack = expedition.inventory.stacks[selected_slot]
	_discard_choice = selected_slot
	dialog.dialog_text = "Discard ALL %d %s from slot %d?%s" % [stack.quantity, stack.definition.display_name, selected_slot + 1,
		" Incoming cargo will fill the freed space." if not expedition.pending_loot.is_empty() else ""]
	dialog.popup_centered(Vector2i(700, 220))


func _ask_discard_incoming() -> void:
	if not ExpeditionRules.can_interact(expedition) or expedition.pending_loot.is_empty():
		return
	var stack: ItemStack = expedition.pending_loot[0]
	_discard_choice = -2
	dialog.dialog_text = "Leave behind ALL %d incoming %s? This resolved room will not generate them again." % [stack.quantity, stack.definition.display_name]
	dialog.popup_centered(Vector2i(700, 220))


func _confirm_discard() -> void:
	var choice: int = _discard_choice
	_discard_choice = -3
	if choice == -3 or not _accept_input():
		return
	if choice == -2:
		ExpeditionRules.discard_pending(expedition)
	else:
		ExpeditionRules.discard_slot(expedition, choice)
	selected_slot = -1
	_refresh()


func _engage() -> void:
	if not _accept_input():
		return
	var room: RoomDefinition = ExpeditionRules.begin_encounter(expedition)
	if room == null:
		return
	battle = BATTLE_SCENE.instantiate() as Control
	battle.set("expedition_mode", true)
	var controller: BattleController = battle.get_node("BattleController") as BattleController
	controller.expedition = expedition
	controller.enemy_definitions = room.enemies
	controller.battle_seed = expedition.rooms[room.id].encounter_seed
	battle.connect("expedition_battle_closed", _close_battle)
	$Margin.hide()
	add_child(battle)


func _close_battle() -> void:
	_finish_battle.call_deferred()


func _finish_battle() -> void:
	if battle == null:
		return
	var controller: BattleController = battle.get_node("BattleController") as BattleController
	if not ExpeditionRules.finish_encounter(expedition, controller.state):
		return
	remove_child(battle)
	battle.queue_free()
	battle = null
	$Margin.show()
	selected_slot = -1
	_refresh()
	(%EndTest as Button).grab_focus()


func _refresh() -> void:
	if expedition == null:
		return
	var room: RoomDefinition = expedition.ship.get_room(expedition.current_room)
	var record: RoomState = expedition.rooms[room.id]
	var idle: bool = ExpeditionRules.can_interact(expedition)
	var travelling: bool = not expedition.destination.is_empty()
	var pending: bool = not expedition.pending_loot.is_empty()
	room_map.visible = not travelling
	room_map.refresh()
	(%SkipCorridor as Button).visible = travelling
	(%EndTest as Button).disabled = travelling or pending
	var entry_power: int = expedition.power if travelling else maxi(0, expedition.power - CombatRules.BALANCE.corridor_power_cost)
	(%Summary as Label).text = "POWER %d/%d | Entry strain after travel +%d | Cargo %d/%d slots | %s" % [
		expedition.power, CombatRules.BALANCE.power_max, CombatRules.room_strain(entry_power),
		expedition.inventory.stacks.size(), expedition.inventory.capacity,
		"EXPEDITION FAILED" if expedition.failed else ("BOSS PLACEHOLDER CLEARED" if expedition.boss_cleared else "Exploring")]
	var crew: PackedStringArray = []
	for member: CrewState in expedition.crew:
		crew.append("%s %s: %s" % [String(member.id).replace("crew_", "C"), member.definition.display_name,
			"DEAD" if member.dead else ("%d HP / %d strain%s" % [member.health, member.strain, " SHAKEN" if member.shaken else ""])])
	(%CrewSummary as Label).text = "   |   ".join(crew)
	(%RoomTitle as Label).text = "Corridor to " + expedition.ship.get_room(expedition.destination).display_name if travelling else room.display_name
	(%RoomDescription as Label).text = room.description
	if record.resolved:
		(%RoomDescription as Label).text += "\n\nResolved once. Backtracking costs power but never regenerates this room's event or loot."
	if expedition.failed:
		(%RoomDescription as Label).text = "No conscious crew remain. All deployed crew were lost. This test expedition has ended. Hub recovery and recruitment arrive in milestone 7."
	var inspection: bool = room.kind in [RoomDefinition.Kind.SALVAGE, RoomDefinition.Kind.HAZARD, RoomDefinition.Kind.SAFE]
	(%InspectAccept as Button).visible = inspection and not record.resolved
	(%InspectLeave as Button).visible = inspection and not record.resolved
	(%InspectAccept as Button).disabled = not idle or pending
	(%InspectLeave as Button).disabled = not idle or pending
	(%InspectAccept as Button).text = "Rest once" if room.kind == RoomDefinition.Kind.SAFE else ("Search / +%d strain" % room.strain_cost if room.kind == RoomDefinition.Kind.HAZARD else "Collect cache")
	(%InspectLeave as Button).text = "Seal / no loot" if room.kind == RoomDefinition.Kind.HAZARD else "Leave / resolve room"
	(%Engage as Button).visible = room.kind in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.BOSS] and not record.resolved
	(%Engage as Button).disabled = not idle or pending
	for index: int in range(inventory_buttons.size()):
		var button: Button = inventory_buttons[index]
		button.disabled = not idle or index >= expedition.inventory.stacks.size()
		button.text = "%02d  EMPTY" % (index + 1)
		button.modulate = Color("77d5d9") if index == selected_slot else Color.WHITE
		if index < expedition.inventory.stacks.size():
			var stack: ItemStack = expedition.inventory.stacks[index]
			button.text = "%02d  %s\nx%d / stack %d" % [index + 1, stack.definition.display_name, stack.quantity, stack.definition.max_stack]
	(%UseCell as Button).disabled = not idle or selected_slot < 0 or selected_slot >= expedition.inventory.stacks.size()
	(%UseCell as Button).text = "Use selected power cell / +%d power" % ContentCatalogue.POWER_CELL.power_restored
	if not (%UseCell as Button).disabled:
		(%UseCell as Button).disabled = expedition.inventory.stacks[selected_slot].definition.power_restored <= 0 or expedition.power >= CombatRules.BALANCE.power_max
	(%DiscardSlot as Button).disabled = not idle or selected_slot < 0 or selected_slot >= expedition.inventory.stacks.size()
	(%DiscardIncoming as Button).visible = pending
	(%DiscardIncoming as Button).disabled = not idle
	(%LootNotice as Label).text = "Select a stack to use a cell or discard it. Power cells restore %d power, outside combat only." % ContentCatalogue.POWER_CELL.power_restored
	if pending:
		var incoming: ItemStack = expedition.pending_loot[0]
		(%LootNotice as Label).text = "HOLD FULL: %d incoming %s. Select a stored stack and discard it to keep cargo, or leave incoming cargo behind. Travel is locked until you decide." % [incoming.quantity, incoming.definition.display_name]
