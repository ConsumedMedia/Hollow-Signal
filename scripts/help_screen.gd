extends "res://scripts/screen_navigation.gd"
## Static, spoiler-free mechanics reference. No campaign mutation.


func _ready() -> void:
	super._ready()
	(%Back as Button).pressed.connect(open_screen.bind("res://scenes/main_menu.tscn"))

