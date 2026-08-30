class_name BattleStage
extends Control
## Layered battle theatre and ordered consumer of resolved CombatEvents.

signal presentation_finished
signal sound_requested(cue: StringName)

const CHARACTER_SCENE: PackedScene = preload("res://scenes/character_presentation.tscn")
const LAYER_SCRIPT: Script = preload("res://presentation/parallax_layer.gd")

@export_range(0.01, 4.0, 0.01) var animation_scale: float = 1.0

var crew_ids: Array[StringName] = []
var enemy_ids: Array[StringName] = []
var active_id: StringName = &""
var _presenters: Dictionary = {}
var _layers: Array[Parallax2D] = []
var _playing: bool = false
var _skip_requested: bool = false
var _generation: int = 0
var _pending_sync: bool = false
var _focus_tween: Tween
var _focused: bool = false
var _damage_popup: Label
var last_damage_amount: int = 0


func _ready() -> void:
	# Keep negative-depth parallax children above the screen background while
	# clip_contents confines the whole theatre to this HUD slot.
	z_index = 10
	clip_contents = true
	resized.connect(_layout_stage)
	_build_layers()
	_build_damage_popup()
	_layout_stage()


func sync_formation(crew: Array[StringName], enemies: Array[StringName], current: StringName, state: CombatState = null) -> void:
	crew_ids = crew.duplicate()
	enemy_ids = enemies.duplicate()
	active_id = current
	if _playing:
		_pending_sync = true
		return
	_apply_formation(state)


func present_events(events: Array[CombatEvent]) -> void:
	_generation += 1
	var generation: int = _generation
	_playing = true
	_skip_requested = false
	for event: CombatEvent in events:
		if generation != _generation or _skip_requested:
			break
		await _present_event(event)
	if generation != _generation:
		return
	_playing = false
	_skip_requested = false
	if _pending_sync:
		_pending_sync = false
		_apply_formation()
	presentation_finished.emit()


func skip_presentation() -> void:
	if not _playing:
		return
	_generation += 1
	_skip_requested = true
	_restore_focus_immediate()
	for presenter: CharacterPresentation in _presenters.values():
		presenter.skip_pose()
	_playing = false
	if _pending_sync:
		_pending_sync = false
		_apply_formation()
	presentation_finished.emit()


func is_presenting() -> bool:
	return _playing


func is_focused() -> bool:
	return _focused


func play_missing_animation_for_test() -> void:
	var presenter: CharacterPresentation = _presenters.values()[0] if not _presenters.is_empty() else null
	if presenter == null:
		presentation_finished.emit()
		return
	_playing = true
	await _play_pose(presenter, &"missing_animation", 0.05)
	_playing = false
	presentation_finished.emit()


func _present_event(event: CombatEvent) -> void:
	match event.kind:
		&"damage":
			await _enter_focus(event.source_id, event.target_id)
			await _play_actor(event.source_id, &"attack", 0.16 * animation_scale)
			await _show_damage(event.target_id, event.amount)
			await _play_actor(event.target_id, &"hurt", 0.12 * animation_scale)
			_impact_scroll()
			await _exit_focus()
		&"healed", &"strain_changed":
			await _enter_focus(event.source_id, event.target_id)
			await _play_actor(event.source_id, &"support", 0.14 * animation_scale)
			await _exit_focus()
		&"moved", &"displaced":
			await _play_actor(event.source_id if event.kind == &"moved" else event.target_id, &"walk", 0.12 * animation_scale)
		&"downed":
			await _play_actor(event.target_id, &"downed", 0.18 * animation_scale)
		&"died", &"defeated":
			await _play_actor(event.target_id, &"death", 0.18 * animation_scale)
		&"dot_damage":
			await _enter_focus(&"", event.target_id)
			await _show_damage(event.target_id, event.amount)
			await _play_actor(event.target_id, &"hurt", 0.12 * animation_scale)
			await _exit_focus()
		_:
			pass


func _play_actor(actor: StringName, requested_pose: StringName, seconds: float) -> void:
	var presenter: CharacterPresentation = _presenters.get(actor) as CharacterPresentation
	if presenter != null:
		await _play_pose(presenter, requested_pose, seconds)


func _play_pose(presenter: CharacterPresentation, requested_pose: StringName, seconds: float) -> void:
	presenter.play_pose(requested_pose, seconds)
	await presenter.pose_finished


func _apply_formation(state: CombatState = null) -> void:
	_focused = false
	var live: Array[StringName] = crew_ids + enemy_ids
	for id: StringName in _presenters.keys():
		if id not in live:
			(_presenters[id] as Node).queue_free()
			_presenters.erase(id)
	for side: int in range(2):
		var ids: Array[StringName] = crew_ids if side == 0 else enemy_ids
		for index: int in range(ids.size()):
			var id: StringName = ids[index]
			var presenter: CharacterPresentation = _presenters.get(id) as CharacterPresentation
			if presenter == null:
				presenter = CHARACTER_SCENE.instantiate() as CharacterPresentation
				add_child(presenter)
				presenter.sound_requested.connect(func(cue: StringName) -> void: sound_requested.emit(cue))
				_presenters[id] = presenter
			var actor: ActorState = state.get_actor(id) if state != null else null
			presenter.configure(id, actor.short_name() if actor != null else String(id).replace("crew_", "C").replace("enemy_", "E"), side == 1)
			presenter.active = id == active_id
			presenter.set_ground_position(_rank_position(side, index))
			if actor != null and actor.is_downed():
				presenter.settle(&"downed")
			else:
				presenter.settle()
			presenter.queue_redraw()


func _rank_position(side: int, rank_index: int) -> Vector2:
	var half_width: float = (size.x - 56.0) * 0.5
	var cell_width: float = half_width / 4.0
	var column: int = 3 - rank_index if side == 0 else rank_index
	return Vector2((column + 0.5) * cell_width + side * (half_width + 56.0), size.y * 0.79)


func _build_layers() -> void:
	for kind: int in range(3):
		var parallax := Parallax2D.new()
		parallax.name = ["DistantParallax", "MachineryParallax", "ForegroundParallax"][kind]
		parallax.scroll_scale = [Vector2(0.15, 0.15), Vector2(0.4, 0.4), Vector2(1.15, 1.15)][kind]
		parallax.repeat_times = 3
		parallax.z_index = [-3, -2, 2][kind]
		var art := SignalParallaxLayer.new()
		art.name = "RepeatableArt"
		art.layer_kind = kind
		parallax.add_child(art)
		add_child(parallax)
		move_child(parallax, kind)
		_layers.append(parallax)


func _build_damage_popup() -> void:
	_damage_popup = Label.new()
	_damage_popup.name = "DamagePopup"
	_damage_popup.add_theme_font_size_override("font_size", 42)
	_damage_popup.add_theme_color_override("font_color", Color("ff765e"))
	_damage_popup.add_theme_color_override("font_shadow_color", Color("11080a"))
	_damage_popup.add_theme_constant_override("shadow_offset_x", 3)
	_damage_popup.add_theme_constant_override("shadow_offset_y", 3)
	_damage_popup.z_index = 20
	_damage_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_popup.visible = false
	add_child(_damage_popup)


func _enter_focus(source_id: StringName, target_id: StringName) -> void:
	if _presenters.is_empty():
		return
	_focused = true
	if animation_scale <= 0.02:
		_set_focus_immediate(source_id, target_id)
		return
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true)
	var source: CharacterPresentation = _presenters.get(source_id) as CharacterPresentation
	var target: CharacterPresentation = _presenters.get(target_id) as CharacterPresentation
	for presenter: CharacterPresentation in _presenters.values():
		var is_subject: bool = presenter == source or presenter == target
		var destination: Vector2 = presenter.position
		if source == target and presenter == source:
			destination = Vector2(size.x * 0.5, size.y * 0.84)
		elif presenter == source:
			destination = Vector2(size.x * 0.34, size.y * 0.84)
		elif presenter == target:
			destination = Vector2(size.x * 0.66, size.y * 0.84)
		_focus_tween.tween_property(presenter, "position", destination, 0.11 * animation_scale)
		_focus_tween.tween_property(presenter, "scale", Vector2.ONE * (1.62 if is_subject else 0.82), 0.11 * animation_scale)
		_focus_tween.tween_property(presenter, "modulate", Color.WHITE if is_subject else Color(0.25, 0.31, 0.34, 0.3), 0.11 * animation_scale)
	for layer: Parallax2D in _layers:
		_focus_tween.tween_property(layer, "modulate", Color(0.48, 0.55, 0.58, 1.0), 0.11 * animation_scale)
	await _focus_tween.finished
	if not _focused:
		return
	for presenter: CharacterPresentation in _presenters.values():
		presenter.set_rest_transform(presenter.position, presenter.scale, presenter.modulate)


func _exit_focus() -> void:
	if not _focused:
		return
	if animation_scale <= 0.02:
		_restore_focus_immediate()
		return
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true)
	for presenter: CharacterPresentation in _presenters.values():
		var ids: Array[StringName] = enemy_ids if presenter.enemy else crew_ids
		var index: int = ids.find(presenter.actor_id)
		var destination: Vector2 = _rank_position(1 if presenter.enemy else 0, index)
		_focus_tween.tween_property(presenter, "position", destination, 0.1 * animation_scale)
		_focus_tween.tween_property(presenter, "scale", Vector2.ONE, 0.1 * animation_scale)
		_focus_tween.tween_property(presenter, "modulate", Color.WHITE, 0.1 * animation_scale)
	for layer: Parallax2D in _layers:
		_focus_tween.tween_property(layer, "modulate", Color.WHITE, 0.1 * animation_scale)
	await _focus_tween.finished
	_focused = false
	for presenter: CharacterPresentation in _presenters.values():
		presenter.set_rest_transform(presenter.position)


func _restore_focus_immediate() -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	_focused = false
	if _damage_popup != null:
		_damage_popup.visible = false
	for presenter: CharacterPresentation in _presenters.values():
		var ids: Array[StringName] = enemy_ids if presenter.enemy else crew_ids
		var index: int = ids.find(presenter.actor_id)
		if index >= 0:
			presenter.set_rest_transform(_rank_position(1 if presenter.enemy else 0, index))
	for layer: Parallax2D in _layers:
		layer.modulate = Color.WHITE


func _show_damage(target_id: StringName, amount: int) -> void:
	var target: CharacterPresentation = _presenters.get(target_id) as CharacterPresentation
	if target == null:
		return
	last_damage_amount = amount
	if animation_scale <= 0.02:
		_damage_popup.visible = false
		return
	_damage_popup.text = "−%d" % amount
	_damage_popup.position = target.position + Vector2(-32.0, -180.0)
	_damage_popup.modulate = Color.WHITE
	_damage_popup.visible = true
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_damage_popup, "position:y", _damage_popup.position.y - 32.0, 0.12 * animation_scale)
	tween.tween_property(_damage_popup, "modulate:a", 0.0, 0.18 * animation_scale).set_delay(0.05 * animation_scale)
	await tween.finished
	_damage_popup.visible = false


func _set_focus_immediate(source_id: StringName, target_id: StringName) -> void:
	var source: CharacterPresentation = _presenters.get(source_id) as CharacterPresentation
	var target: CharacterPresentation = _presenters.get(target_id) as CharacterPresentation
	for presenter: CharacterPresentation in _presenters.values():
		var is_subject: bool = presenter == source or presenter == target
		var destination: Vector2 = presenter.position
		if source == target and presenter == source:
			destination = Vector2(size.x * 0.5, size.y * 0.84)
		elif presenter == source:
			destination = Vector2(size.x * 0.34, size.y * 0.84)
		elif presenter == target:
			destination = Vector2(size.x * 0.66, size.y * 0.84)
		presenter.set_rest_transform(destination, Vector2.ONE * (1.62 if is_subject else 0.82),
			Color.WHITE if is_subject else Color(0.25, 0.31, 0.34, 0.3))
	for layer: Parallax2D in _layers:
		layer.modulate = Color(0.48, 0.55, 0.58, 1.0)


func _layout_stage() -> void:
	for index: int in range(_layers.size()):
		var parallax: Parallax2D = _layers[index]
		parallax.repeat_size = Vector2(maxf(size.x, 1.0), 0.0)
		(parallax.get_node("RepeatableArt") as SignalParallaxLayer).configure(index, size)
	for side: int in range(2):
		var ids: Array[StringName] = crew_ids if side == 0 else enemy_ids
		for index: int in range(ids.size()):
			var presenter: CharacterPresentation = _presenters.get(ids[index]) as CharacterPresentation
			if presenter != null:
				presenter.set_ground_position(_rank_position(side, index))


func _impact_scroll() -> void:
	for index: int in range(_layers.size()):
		var parallax: Parallax2D = _layers[index]
		parallax.scroll_offset.x = float([2, 5, 9][index])
	var tween: Tween = create_tween()
	for index: int in range(_layers.size()):
		tween.parallel().tween_property(_layers[index], "scroll_offset:x", 0.0, 0.1)
