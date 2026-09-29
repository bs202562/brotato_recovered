extends Node


func _ready() -> void:
	call_deferred("_launch")


func _launch() -> void:
	DebugService.character_workbench_enabled = true
	DebugService.invulnerable = true
	DebugService.hide_wave_timer = true
	DebugService.custom_wave_duration = 60 * 60

	RunData.reset()
	RunData.set_player_count(1, true)
	var character = _find_character(DebugService.character_workbench_character_id)
	if character == null:
		character = ItemService.characters[0]
		DebugService.character_workbench_character_id = character.my_id

	RunData.add_character(character, 0)
	_add_preview_weapon(character)
	RunData.add_starting_items_and_weapons()
	RunData.players_data[0].current_level = max(1, DebugService.character_workbench_level)
	RunData.current_wave = 1
	RunData.current_difficulty = 0
	RunData.enabled_dlcs = ProgressData.get_active_dlc_ids()
	RunData.current_run_accessibility_settings = ProgressData.settings.enemy_scaling.duplicate()

	var difficulty = ItemService.get_element(ItemService.difficulties, Keys.empty_hash, 0)
	if difficulty != null:
		for effect in difficulty.effects:
			effect.apply(0)

	RunData.reset_elites_spawn()
	RunData.init_elites_spawn()
	RunData.init_events_nightmare()
	RunData.init_bosses_spawn()
	get_tree().change_scene(MenuData.game_scene)


func _find_character(character_id: String):
	for character in ItemService.characters:
		if character.my_id == character_id:
			return character
	return null


func _add_preview_weapon(character: CharacterData) -> void:
	if character.starting_weapons.empty():
		return
	var weapon = character.starting_weapons[0]
	RunData.add_weapon(weapon, 0, true)
