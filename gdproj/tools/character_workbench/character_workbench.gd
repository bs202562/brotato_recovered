extends CanvasLayer

const SPAWN_INTERVAL_MIN := 0.15
const SPAWN_INTERVAL_MAX := 5.0
const MAX_ACTIVE_ENEMIES := 80

var _main: Main
var _player: Player
var _player_anchor := Vector2.ZERO
var _character_select: OptionButton
var _enemy_select: OptionButton
var _level_spin: SpinBox
var _spawn_interval: HSlider
var _spawn_label: Label
var _test_toggle: CheckButton
var _effect_text: RichTextLabel
var _status: Label
var _spawn_timer: Timer
var _rotation_degrees := 0.0
var _smoke_test_started := false


func _ready() -> void:
	_main = get_tree().current_scene
	_build_ui()
	_populate_characters()
	_populate_enemies()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = 1.0
	add_child(_spawn_timer)
	_spawn_timer.connect("timeout", self, "_spawn_enemy")
	_test_toggle.pressed = DebugService.character_workbench_test_mode
	if _test_toggle.pressed:
		_spawn_timer.start()
	call_deferred("_bind_player")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if _test_toggle.pressed:
		_player.global_position = _player_anchor
		_player._can_move = false
		_player._current_movement = Vector2.ZERO


func _build_ui() -> void:
	var panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.margin_left = 12
	panel.margin_top = 12
	panel.margin_right = 352
	panel.margin_bottom = -12
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_constant_override("margin_left", 14)
	margin.add_constant_override("margin_top", 12)
	margin.add_constant_override("margin_right", 14)
	margin.add_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root = VBoxContainer.new()
	root.add_constant_override("separation", 8)
	margin.add_child(root)
	_add_title(root, "CHARACTER WORKBENCH")
	root.add_child(_make_label("Character (selection reloads the arena)"))
	_character_select = OptionButton.new()
	_character_select.connect("item_selected", self, "_on_character_selected")
	root.add_child(_character_select)

	var level_row = HBoxContainer.new()
	level_row.add_child(_make_label("Level"))
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 100
	_level_spin.step = 1
	_level_spin.value = DebugService.character_workbench_level
	_level_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_spin.connect("value_changed", self, "_on_level_changed")
	level_row.add_child(_level_spin)
	root.add_child(level_row)

	root.add_child(_make_label("Character rotation"))
	var rotation_row = HBoxContainer.new()
	for data in [["-45 deg", -45.0], ["Reset", 0.0], ["+45 deg", 45.0]]:
		var button = Button.new()
		button.text = data[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.connect("pressed", self, "_on_rotate_pressed", [data[1], data[0] == "Reset"])
		rotation_row.add_child(button)
	root.add_child(rotation_row)

	_add_separator(root)
	_test_toggle = CheckButton.new()
	_test_toggle.text = "Tower-defense test (lock player)"
	_test_toggle.connect("toggled", self, "_on_test_mode_toggled")
	root.add_child(_test_toggle)
	root.add_child(_make_label("Enemy type"))
	_enemy_select = OptionButton.new()
	root.add_child(_enemy_select)

	_spawn_label = _make_label("Spawn interval: 1.00 s")
	root.add_child(_spawn_label)
	_spawn_interval = HSlider.new()
	_spawn_interval.min_value = SPAWN_INTERVAL_MIN
	_spawn_interval.max_value = SPAWN_INTERVAL_MAX
	_spawn_interval.step = 0.05
	_spawn_interval.value = 1.0
	_spawn_interval.connect("value_changed", self, "_on_spawn_interval_changed")
	root.add_child(_spawn_interval)

	var enemy_row = HBoxContainer.new()
	var spawn_button = Button.new()
	spawn_button.text = "Spawn now"
	spawn_button.connect("pressed", self, "_spawn_enemy")
	enemy_row.add_child(spawn_button)
	var clear_button = Button.new()
	clear_button.text = "Clear enemies"
	clear_button.connect("pressed", self, "_clear_enemies")
	enemy_row.add_child(clear_button)
	root.add_child(enemy_row)

	_add_separator(root)
	_add_title(root, "SKILL / FX TRIGGERS")
	var trigger_row = GridContainer.new()
	trigger_row.columns = 2
	_add_trigger_button(trigger_row, "Take damage", "_trigger_damage")
	_add_trigger_button(trigger_row, "Heal", "_trigger_heal")
	_add_trigger_button(trigger_row, "Reset weapon CD", "_trigger_weapon_cooldown")
	_add_trigger_button(trigger_row, "Victory / dance", "_trigger_dance")
	root.add_child(trigger_row)

	root.add_child(_make_label("Active character effects (live RunData)"))
	_effect_text = RichTextLabel.new()
	_effect_text.bbcode_enabled = true
	_effect_text.rect_min_size = Vector2(0, 150)
	_effect_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_effect_text)

	_status = _make_label("Connecting to the live player...")
	_status.autowrap = true
	root.add_child(_status)
	var exit_button = Button.new()
	exit_button.text = "Exit workbench"
	exit_button.connect("pressed", self, "_exit_workbench")
	root.add_child(exit_button)


func _bind_player() -> void:
	if _main._players.empty():
		yield(get_tree().create_timer(0.1), "timeout")
		call_deferred("_bind_player")
		return
	_player = _main._players[0]
	_player_anchor = _player.global_position
	_apply_rotation()
	_update_effect_text()
	_status.text = "Live player connected. Safety cap: %s active enemies." % MAX_ACTIVE_ENEMIES
	if OS.get_environment("BROTATO_WORKBENCH_SMOKE") == "1" and not _smoke_test_started:
		_smoke_test_started = true
		call_deferred("_run_smoke_test")


func _populate_characters() -> void:
	var selected := 0
	for i in ItemService.characters.size():
		var character = ItemService.characters[i]
		_character_select.add_item(character.get_name_text())
		_character_select.set_item_metadata(i, character.my_id)
		if character.my_id == DebugService.character_workbench_character_id:
			selected = i
	_character_select.select(selected)


func _populate_enemies() -> void:
	for entity in ItemService.entities:
		if not entity is ItemEnemy or entity.is_boss:
			continue
		var scene_path = entity.resource_path.replace("_item.tres", ".tscn")
		if not ResourceLoader.exists(scene_path):
			continue
		_enemy_select.add_item(entity.get_name_text())
		_enemy_select.set_item_metadata(_enemy_select.get_item_count() - 1, scene_path)


func _on_character_selected(index: int) -> void:
	DebugService.character_workbench_character_id = _character_select.get_item_metadata(index)
	_restart_workbench()


func _on_level_changed(value: float) -> void:
	DebugService.character_workbench_level = int(value)
	if not is_instance_valid(_player):
		return
	RunData.players_data[0].current_level = int(value)
	RunData.emit_signal("xp_added", RunData.get_player_xp(0), RunData.get_next_level_xp_needed(0), 0)
	RunData.emit_signal("stats_updated", 0)
	_status.text = "Level set to %s. This does not auto-pick %s level-up upgrades." % [int(value), max(0, int(value) - 1)]


func _on_rotate_pressed(delta: float, reset: bool) -> void:
	_rotation_degrees = 0.0 if reset else wrapf(_rotation_degrees + delta, -180.0, 180.0)
	_apply_rotation()


func _apply_rotation() -> void:
	if is_instance_valid(_player) and _player.has_node("Animation"):
		_player.get_node("Animation").rotation_degrees = _rotation_degrees
		_status.text = "Character rotation: %s deg" % int(_rotation_degrees)


func _on_test_mode_toggled(enabled: bool) -> void:
	DebugService.character_workbench_test_mode = enabled
	if not is_instance_valid(_player):
		return
	_player._can_move = not enabled
	if enabled:
		_player_anchor = _player.global_position
		_spawn_timer.start()
		_status.text = "Tower-defense test ON: player locked, enemies keep spawning."
	else:
		_spawn_timer.stop()
		_status.text = "Tower-defense test OFF: player movement restored."


func _on_spawn_interval_changed(value: float) -> void:
	_spawn_timer.wait_time = clamp(value, SPAWN_INTERVAL_MIN, SPAWN_INTERVAL_MAX)
	_spawn_label.text = "Spawn interval: %.2f s" % _spawn_timer.wait_time


func _spawn_enemy() -> void:
	if not is_instance_valid(_main) or _enemy_select.get_item_count() == 0:
		return
	if _main._entity_spawner.enemies.size() >= MAX_ACTIVE_ENEMIES:
		_status.text = "Safety cap reached: %s active enemies." % MAX_ACTIVE_ENEMIES
		return
	var scene_path = _enemy_select.get_item_metadata(_enemy_select.selected)
	var enemy_scene = load(scene_path)
	if enemy_scene == null:
		_status.text = "Failed to load enemy: %s" % scene_path
		return
	var group = WaveGroupData.new()
	group.spawn_edge_of_map = true
	group.area = 64
	var unit = WaveUnitData.new()
	unit.type = EntityType.ENEMY
	unit.unit_scene = enemy_scene
	unit.min_number = 1
	unit.max_number = 1
	group.wave_units_data = [unit]
	_main._entity_spawner.on_group_spawn_timing_reached(group)
	_status.text = "Queued enemy: %s" % _enemy_select.get_item_text(_enemy_select.selected)


func _clear_enemies() -> void:
	if not is_instance_valid(_main):
		return
	for enemy in _main._entity_spawner.enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.can_drop_loot = false
			enemy.die()
	_status.text = "Normal enemies cleared."


func _trigger_damage() -> void:
	if not is_instance_valid(_player):
		return
	_player.on_damage_effect(max(1, int(_player.max_stats.health * 0.25)), false, false, null)
	_status.text = "Applied 25% max-HP damage for hit / low-HP triggers."


func _trigger_heal() -> void:
	if not is_instance_valid(_player):
		return
	_player.on_healing_effect(max(1, int(_player.max_stats.health * 0.25)))
	_status.text = "Applied a 25% max-HP heal trigger."


func _trigger_weapon_cooldown() -> void:
	if is_instance_valid(_player):
		_player.reset_weapons_cd()
		_status.text = "All weapon cooldowns reset."


func _trigger_dance() -> void:
	if is_instance_valid(_player):
		_player.dance()
		_status.text = "Playing the character dance animation."


func _update_effect_text() -> void:
	var character = RunData.get_player_character(0)
	if character == null:
		_effect_text.bbcode_text = "[color=red]No character data[/color]"
		return
	var text = character.get_effects_text(0)
	_effect_text.bbcode_text = text if text != "" else "[color=#aaaaaa]No displayable effect text[/color]"


func _restart_workbench() -> void:
	DebugService.current_character_workbench = null
	get_tree().change_scene("res://tools/character_workbench/character_workbench_launcher.tscn")


func _exit_workbench() -> void:
	DebugService.character_workbench_enabled = false
	DebugService.character_workbench_test_mode = false
	DebugService.current_character_workbench = null
	DebugService.reset()
	RunData.reset()
	get_tree().change_scene(MenuData.title_screen_scene)


func _run_smoke_test() -> void:
	_test_toggle.pressed = true
	_spawn_enemy()
	_on_rotate_pressed(45.0, false)
	_level_spin.value = 12
	yield(get_tree().create_timer(2.0), "timeout")
	var image = get_viewport().get_texture().get_data()
	image.flip_y()
	var screenshot_path = "user://character_workbench_smoke.png"
	var screenshot_error = image.save_png(screenshot_path)
	print("WORKBENCH_SMOKE player=", is_instance_valid(_player),
		" enemies=", _main._entity_spawner.enemies.size(),
		" queued=", _main._entity_spawner.queue_to_spawn.size(),
		" level=", RunData.get_player_level(0),
		" rotation=", _rotation_degrees,
		" screenshot_error=", screenshot_error,
		" screenshot=", ProjectSettings.globalize_path(screenshot_path))
	get_tree().quit()


func _add_title(parent: Control, text: String) -> void:
	var label = _make_label(text)
	parent.add_child(label)


func _add_separator(parent: Control) -> void:
	parent.add_child(HSeparator.new())


func _add_trigger_button(parent: Control, text: String, method: String) -> void:
	var button = Button.new()
	button.text = text
	button.connect("pressed", self, method)
	parent.add_child(button)


func _make_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	return label
