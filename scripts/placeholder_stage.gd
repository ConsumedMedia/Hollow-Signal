class_name PlaceholderStage
extends Control
## Original geometric stand-ins. This script draws; it never resolves combat.

@export_enum("Ship", "Battle") var display: int = 0

const HULL: Color = Color("203343")
const EDGE: Color = Color("4d6674")
const CYAN: Color = Color("77d5d9")
const RUST: Color = Color("dc9069")

# Presentation flags only, supplied by the battle screen from resolved state.
var crew_defeated: bool = false
var enemy_defeated: bool = false


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if display == 0:
		var scale_factor: float = minf(size.x / 800.0, size.y / 460.0)
		var origin: Vector2 = (size - Vector2(800, 460) * scale_factor) * 0.5
		draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
		_draw_ship()
	else:
		_draw_battle()


func _draw_ship() -> void:
	for row: int in range(1, 6):
		draw_line(Vector2(32, row * 72), Vector2(768, row * 72), Color("182735"), 1.0)
	for column: int in range(1, 11):
		draw_line(Vector2(column * 72, 20), Vector2(column * 72, 440), Color("182735"), 1.0)
	draw_rect(Rect2(145, 180, 500, 105), HULL)
	draw_rect(Rect2(245, 125, 215, 210), HULL)
	draw_rect(Rect2(110, 205, 595, 52), HULL)
	draw_rect(Rect2(245, 125, 215, 210), EDGE, false, 2.0)
	draw_rect(Rect2(145, 180, 500, 105), EDGE, false, 2.0)
	draw_rect(Rect2(590, 207, 85, 48), Color("375460"))
	draw_rect(Rect2(120, 208, 18, 42), RUST)
	draw_rect(Rect2(295, 160, 90, 35), Color("375460"))
	draw_line(Vector2(190, 232), Vector2(565, 232), CYAN, 3.0)
	draw_circle(Vector2(485, 232), 7.0, CYAN)
	draw_line(Vector2(485, 232), Vector2(540, 90), CYAN, 2.0)
	draw_line(Vector2(540, 90), Vector2(690, 90), CYAN, 2.0)
	draw_circle(Vector2(485, 232), 30.0, Color("345664"), false, 2.0)


func _draw_battle() -> void:
	var floor_y: float = size.y * 0.8
	var bay_width: float = size.x / 9.0
	draw_rect(Rect2(Vector2.ZERO, size), Color("101d29"))
	for column: int in range(9):
		draw_rect(Rect2(column * bay_width + 16, 20, bay_width - 32, floor_y - 40), Color("172936"))
		draw_rect(Rect2(column * bay_width + 24, 30, bay_width - 48, 6), EDGE)
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color("0d1620"))
	draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), EDGE, 3.0)
	draw_line(Vector2(size.x * 0.5, 50), Vector2(size.x * 0.5, floor_y - 20), Color("344653"), 2.0)
	var actor_scale: float = minf(size.y / 400.0, 1.2)
	draw_set_transform(Vector2(size.x * 0.25, floor_y - 5), 0.0, Vector2.ONE * actor_scale)
	_draw_actor(Vector2.ZERO, CYAN.darkened(0.65) if crew_defeated else CYAN)
	draw_set_transform(Vector2(size.x * 0.75, floor_y - 5), 0.0, Vector2.ONE * actor_scale)
	_draw_actor(Vector2.ZERO, RUST.darkened(0.65) if enemy_defeated else RUST)


func _draw_actor(feet: Vector2, colour: Color) -> void:
	draw_rect(Rect2(feet + Vector2(-60, 0), Vector2(120, 10)), Color("070d14"))
	draw_rect(Rect2(feet + Vector2(-32, -68), Vector2(25, 68)), colour.darkened(0.4))
	draw_rect(Rect2(feet + Vector2(7, -68), Vector2(25, 68)), colour.darkened(0.4))
	draw_rect(Rect2(feet + Vector2(-47, -161), Vector2(94, 100)), colour.darkened(0.2))
	draw_rect(Rect2(feet + Vector2(-63, -158), Vector2(20, 83)), colour.darkened(0.35))
	draw_rect(Rect2(feet + Vector2(43, -158), Vector2(20, 83)), colour.darkened(0.35))
	draw_rect(Rect2(feet + Vector2(-30, -218), Vector2(60, 53)), colour)
	draw_rect(Rect2(feet + Vector2(-23, -207), Vector2(46, 18)), Color("101d29"))
