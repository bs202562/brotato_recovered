extends Control
class_name UITimeline

signal run_title_move_right()
signal run_title_move_left()

export (PackedScene) var ui_timeline_slot
onready var _timeline_slot_container: HBoxContainer = $"%timeline_slot_container"
onready var _current_position: Control = $"%current_position"
onready var _icon_current: TextureRect = $"%icon_current"

var current_position: int

func _set_timeline() -> void :
	if RunData.current_wave <= 20 and not (RunData.is_endless_run and RunData.current_wave >= 10):
		if RunData.current_wave >= 1:
			
			_set_timeline_custom(RunData.current_wave, RunData.players_data[0].current_character)
		else:
			_set_timeline_custom(RunData.current_wave, RunData.players_data[0].current_character, RunData.current_wave, RunData.current_wave + 20)
	else:
		
		_set_timeline_custom(RunData.current_wave, RunData.players_data[0].current_character, RunData.current_wave - 10, RunData.current_wave + 10)

	if RunData.current_wave <= 5:
		emit_signal("run_title_move_right")
	else:
		emit_signal("run_title_move_left")


func _set_timeline_custom(current_position_index: int, character: CharacterData, from_wave: int = 1, to_wave: int = 20) -> void :
	current_position = current_position_index
	for child in _timeline_slot_container.get_children():
		child.queue_free()


	for index in range(from_wave, to_wave + 1):
		var new_slot: UITimelineSlot = ui_timeline_slot.instance()
		var icons = []
		var icon: Texture = null
		var color: Color = _check_color_point(index, index < current_position)
		var shadow_icon: bool = false
		if index < current_position:
			shadow_icon = true
		for elite_index in RunData.elites_spawn.size():
			if RunData.elites_spawn[elite_index][0] == index:
				var event: int = RunData.elites_spawn[elite_index][1]
				match event:
					EliteType.ELITE:
						icon = ItemService.get_icon(Keys.icon_elite_hash)
						icons.append([icon, null])
					EliteType.HORDE:
						icon = ItemService.get_icon(Keys.icon_horde_hash)
						icons.append([icon, null])

		for event_index in RunData.events_spawn.size():
			if RunData.events_spawn[event_index][0] == index:
				var event: String = RunData.events_spawn[event_index][1]
				match event:
					"fog_of_war":
						icon = ItemService.get_icon(Keys.icon_fog_of_war_hash)
						icons.append([icon, null])
					"bullet_hell":
						icon = ItemService.get_icon(Keys.icon_bullet_hell_hash)
						icons.append([icon, UIService.projectile_material])

		if index == 20:
			if RunData.current_difficulty >= 5:
				icon = ItemService.get_icon(Keys.icon_two_bosses_hash)
				icons.append([icon, null])
			else:
				icon = ItemService.get_icon(Keys.icon_boss_hash)
				icons.append([icon, null])

		_timeline_slot_container.add_child(new_slot)
		new_slot._set_slot(index, icons, color, shadow_icon)

		if index == current_position:
			new_slot._up_icon()

	_icon_current.texture = character.icon

	yield(get_tree(), "physics_frame")
	yield(get_tree(), "physics_frame")
	for child in _timeline_slot_container.get_children():
		if child.value == current_position:
			_current_position.rect_global_position.x = child.rect_global_position.x + (child.rect_size.x * 0.5)
			break


func _advance_player(offset: int = 1):
	var start_position: Vector2 = _current_position.rect_global_position
	var end_position: Vector2
	for child in _timeline_slot_container.get_children():
		if child.value == current_position + offset:
			end_position = Vector2(child.rect_global_position.x + (child.rect_size.x * 0.5), _current_position.rect_global_position.y)
			break

	var tween: = Tween.new()
	add_child(tween)
	tween.interpolate_property(_current_position, "rect_global_position", start_position, end_position, abs(float(offset)) * 1.5, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	tween.start()

	if offset > 0:
		for child in _timeline_slot_container.get_children():
			if child.value >= current_position and child.value < current_position + offset:
				child._set_color(_check_color_point(child.value, true))
	elif offset < 0:
		for child in _timeline_slot_container.get_children():
			if child.value <= current_position and child.value > current_position + offset:
				child._set_color(_check_color_point(child.value, false))


func _check_color_point(index: int, player_passed_on_it: bool) -> Color:
	var color: Color
	if player_passed_on_it:
		color = Color(1, 1, 0)
	else:
		color = Color(1, 1, 1)
	for elite_index in RunData.elites_spawn.size():
		if RunData.elites_spawn[elite_index][0] == index:
			var event: int = RunData.elites_spawn[elite_index][1]
			match event:
				EliteType.ELITE:
					if not player_passed_on_it:
						color = ProgressData.settings.color_negative
					else:
						color = Color(ProgressData.settings.color_negative).linear_interpolate(color, 0.5)
				EliteType.HORDE:
					if not player_passed_on_it:
						color = ProgressData.settings.color_negative
					else:
						color = Color(ProgressData.settings.color_negative).linear_interpolate(color, 0.5)
		if index == 20:
			if index >= current_position:
				color = ProgressData.settings.color_negative
			else:
				color = Color(ProgressData.settings.color_negative).linear_interpolate(color, 0.5)
	return color
