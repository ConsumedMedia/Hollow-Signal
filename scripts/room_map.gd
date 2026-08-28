class_name RoomMap
extends Control
## Authored layout view; buttons ask the expedition rules to travel.
signal room_selected(room_id: StringName)
var expedition: ExpeditionState
var buttons: Dictionary[StringName, Button] = {}

func _ready() -> void:
	resized.connect(_layout_buttons)

func configure(state: ExpeditionState) -> void:
	expedition = state
	for room: RoomDefinition in state.ship.rooms:
		var button: Button = Button.new()
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void: room_selected.emit(room.id))
		add_child(button)
		buttons[room.id] = button
	refresh()

func refresh() -> void:
	if expedition == null:
		return
	for room: RoomDefinition in expedition.ship.rooms:
		var button: Button = buttons[room.id]
		var record: RoomState = expedition.rooms[room.id]
		var marker: String = "HERE" if room.id == expedition.current_room else ("CLEARED" if record.resolved else ("VISITED" if record.visited else "UNVISITED"))
		button.text = room.display_name + "\n" + marker
		button.disabled = not ExpeditionRules.travel_reason(expedition, room.id).is_empty()
		button.tooltip_text = room.description + "\n" + ExpeditionRules.travel_reason(expedition, room.id)
		button.modulate = Color("77d5d9") if room.id == expedition.current_room else Color.WHITE
	_layout_buttons()

func _position(room: RoomDefinition) -> Vector2:
	var width: float = (size.x - 5.0 * 12.0) / 6.0
	return Vector2(room.map_column * (width + 12.0), room.map_row * 92.0)

func _layout_buttons() -> void:
	if expedition == null:
		return
	var width: float = (size.x - 5.0 * 12.0) / 6.0
	for room: RoomDefinition in expedition.ship.rooms:
		buttons[room.id].position = _position(room)
		buttons[room.id].size = Vector2(width, 84)
	queue_redraw()

func _draw() -> void:
	if expedition == null:
		return
	var offset: Vector2 = Vector2((size.x - 60.0) / 12.0, 42)
	for room: RoomDefinition in expedition.ship.rooms:
		for neighbor: StringName in room.links:
			if String(room.id) < String(neighbor):
				draw_line(_position(room) + offset, _position(expedition.ship.get_room(neighbor)) + offset, Color("4d6674"), 4.0)
