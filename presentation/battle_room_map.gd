class_name BattleRoomMap
extends Control
## Read-only expedition schematic for the combat HUD. Travel remains in ExpeditionRules.

const UNVISITED: Color = Color("263844")
const VISITED: Color = Color("58717d")
const RESOLVED: Color = Color("77d5d9")
const CURRENT: Color = Color("f2a65a")

var expedition: ExpeditionState


func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(state: ExpeditionState) -> void:
	expedition = state
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func displayed_room_id() -> StringName:
	if expedition == null:
		return &""
	if not expedition.current_room.is_empty():
		return expedition.current_room
	var ship: ShipDefinition = _ship()
	return ship.entry_id if ship != null else &""


func _ship() -> ShipDefinition:
	if expedition != null and expedition.ship != null:
		return expedition.ship
	# Standalone battle tests have no exploration runtime. Showing the authored
	# schematic keeps this presentation test useful without mutating its state.
	return ContentCatalogue.SHIP


func _point(room: RoomDefinition) -> Vector2:
	var usable: Vector2 = Vector2(maxf(size.x - 44.0, 1.0), maxf(size.y - 56.0, 1.0))
	return Vector2(22.0 + usable.x * float(room.map_column) / 5.0,
		34.0 + usable.y * float(room.map_row) / 2.0)


func _draw() -> void:
	var ship: ShipDefinition = _ship()
	if ship == null:
		return
	draw_string(ThemeDB.fallback_font, Vector2(14.0, 20.0), "SHIP ROUTE / CURRENT POSITION", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("9fb3bc"))
	for room: RoomDefinition in ship.rooms:
		for neighbor: StringName in room.links:
			if String(room.id) < String(neighbor):
				draw_line(_point(room), _point(ship.get_room(neighbor)), Color("344d59"), 3.0)
	var current: StringName = displayed_room_id()
	for room: RoomDefinition in ship.rooms:
		var colour: Color = UNVISITED
		var record: RoomState = expedition.rooms.get(room.id) as RoomState if expedition != null else null
		if record != null and record.visited:
			colour = RESOLVED if record.resolved else VISITED
		if room.id == current:
			colour = CURRENT
		var point: Vector2 = _point(room)
		draw_rect(Rect2(point - Vector2(11.0, 9.0), Vector2(22.0, 18.0)), colour, true)
		draw_rect(Rect2(point - Vector2(11.0, 9.0), Vector2(22.0, 18.0)), Color("b7c8cf"), false, 1.0)
		if room.id == current:
			draw_arc(point, 16.0, 0.0, TAU, 20, CURRENT, 2.0)
		draw_string(ThemeDB.fallback_font, point + Vector2(-30.0, 25.0), _short_label(room.id), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 11, Color("c7d4d8"))


func _short_label(room_id: StringName) -> String:
	match room_id:
		&"airlock": return "Airlock"
		&"receiving": return "Receiving"
		&"junction": return "Junction"
		&"salvage": return "Salvage"
		&"hazard": return "Pressure"
		&"safe_room": return "Safe room"
		&"containment": return "Contain"
		&"signal_core": return "Signal core"
		_: return String(room_id).left(10)
