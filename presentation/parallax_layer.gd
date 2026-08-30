class_name SignalParallaxLayer
extends Node2D
## Draws one repeatable strip. Parallax2D owns scrolling and repetition.

@export_enum("Distant", "Machinery", "Foreground") var layer_kind: int = 0
var canvas_size: Vector2 = Vector2(1600.0, 300.0)


func configure(kind: int, new_size: Vector2) -> void:
	layer_kind = kind
	canvas_size = new_size
	queue_redraw()


func _draw() -> void:
	match layer_kind:
		0:
			_draw_distant()
		1:
			_draw_machinery()
		_:
			_draw_foreground()


func _draw_distant() -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color("0b1622"))
	for index: int in range(12):
		var x: float = canvas_size.x * (float(index) + 0.5) / 12.0
		var y: float = 18.0 + float((index * 37) % maxi(24, int(canvas_size.y * 0.46)))
		draw_circle(Vector2(x, y), 1.5 if index % 3 else 2.5, Color("385767"))
	draw_line(Vector2(0.0, canvas_size.y * 0.48), Vector2(canvas_size.x, canvas_size.y * 0.48), Color("172b39"), 2.0)


func _draw_machinery() -> void:
	var floor_y: float = canvas_size.y * 0.78
	for bay: int in range(8):
		var bay_width: float = canvas_size.x / 8.0
		var left: float = bay * bay_width + 10.0
		draw_rect(Rect2(left, 20.0, bay_width - 20.0, floor_y - 28.0), Color("172936"))
		draw_rect(Rect2(left + 10.0, 32.0, bay_width - 40.0, 5.0), Color("4d6674"))
		draw_line(Vector2(left + bay_width * 0.25, 42.0), Vector2(left + bay_width * 0.25, floor_y - 14.0), Color("294553"), 3.0)
	draw_rect(Rect2(0.0, floor_y, canvas_size.x, canvas_size.y - floor_y), Color("0a1119"))
	draw_line(Vector2(0.0, floor_y), Vector2(canvas_size.x, floor_y), Color("4d6674"), 3.0)


func _draw_foreground() -> void:
	var bottom: float = canvas_size.y
	# Frame the action at the edges; do not place opaque braces across faces.
	draw_line(Vector2(-12.0, 0.0), Vector2(78.0, bottom), Color("060b11", 0.72), 18.0)
	draw_line(Vector2(canvas_size.x + 12.0, 0.0), Vector2(canvas_size.x - 78.0, bottom), Color("060b11", 0.72), 18.0)
	draw_line(Vector2(0.0, 8.0), Vector2(canvas_size.x, 8.0), Color("070d14", 0.82), 14.0)
