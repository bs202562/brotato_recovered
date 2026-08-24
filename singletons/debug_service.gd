extends Node

@export var debug_menu: PackedScene

@export var starting_wave: = 1 # (int, 1, 1000)
@export var starting_gold: int = 30
@export var invulnerable: bool = false
@export var invisible: bool = false
@export var one_shot_enemies: bool = false
@export var slow_motion: bool = false
@export var instant_waves: bool = false
@export var custom_wave_duration: int = - 1
@export var no_fullscreen_on_launch: bool = true
@export var debug_weapons: Array = [] # (Array, Resource)
@export var debug_items: Array = [] # (Array, Resource)
@export var remove_starting_weapons: bool = false
@export var add_all_weapons: bool = false
@export var add_all_items: bool = false
@export var curse_debug_items_and_weapons: bool = false
@export var unlock_all_chars: bool = false
@export var unlock_all_challenges: bool = false
@export var unlock_all_difficulties: bool = false
@export var generate_full_unlocked_save_file: bool = false
@export var reinitialize_save: bool = false
@export var reinitialize_store_data: bool = false
@export var disable_saving: bool = false
@export var randomize_equipment: bool = false
@export var randomize_waves: bool = false
@export var hide_wave_timer: bool = false
@export var hide_hud: bool = false
@export var hide_floating_text: bool = false
@export var nullify_enemy_speed: bool = false
@export var always_drop_crates: bool = false
@export var nb_enemies_mult = 1.0 # (float, 0.0, 10.0, 0.1)
@export var no_enemies: bool = false
@export var no_entities: bool = false
@export var spawn_debug_enemies: bool = false
@export var debug_enemies: Array = [] # (Array, Resource)
@export var spawn_specific_elite: String = ""
@export var spawn_specific_boss: String = ""
@export var force_item_in_shop: String = ""

@export var coop_multiple_keyboard_inputs: bool = false
@export var has_dlc: bool = true
@export var no_skin: bool = false

@export var enable_time_scale_buttons: bool = false
@export var always_curse: bool = false
var curse_enemy_spawn = false
@export var spawn_horde: bool = false
@export var display_fps: bool = false

var debug_items_added: = [false, false, false, false]
var debug_weapons_added: = [false, false, false, false]
var starting_weapons_removed: = [false, false, false, false]

var current_debug_menu


func reset_for_new_run() -> void :
	for i in 4:
		debug_items_added[i] = false
		debug_weapons_added[i] = false
		starting_weapons_removed[i] = false


func _input(event):
	if OS.is_debug_build() and event.is_action_pressed("open_debug_menu"):
		if not is_instance_valid(current_debug_menu):
			current_debug_menu = debug_menu.instantiate()
			if get_tree().current_scene is Main:
				get_tree().current_scene.get_node("UI").add_child(current_debug_menu)
			else:
				get_tree().current_scene.add_child(current_debug_menu)


func reset() -> void :
	starting_wave = 1
	starting_gold = 30
	invulnerable = false
	invisible = false
	one_shot_enemies = false
	slow_motion = false
	instant_waves = false
	no_fullscreen_on_launch = true
	debug_weapons = []
	debug_items = []
	remove_starting_weapons = false
	add_all_weapons = false
	add_all_items = false
	unlock_all_chars = false
	unlock_all_challenges = false
	unlock_all_difficulties = false
	generate_full_unlocked_save_file = false
	reinitialize_save = false
	reinitialize_store_data = false
	disable_saving = false
	randomize_equipment = false
	randomize_waves = false
	hide_wave_timer = false
	hide_hud = false
	hide_floating_text = false
	nullify_enemy_speed = false
	no_enemies = false
	coop_multiple_keyboard_inputs = false
	debug_enemies = []
	spawn_specific_elite = ""


func handle_player_spawn_debug_options(player_index: int) -> void :
	if remove_starting_weapons and not starting_weapons_removed[player_index]:
		RunData.remove_all_weapons(player_index)
		starting_weapons_removed[player_index] = true

	if randomize_equipment:
		_randomize_equipement(player_index)

	if add_all_weapons and not debug_weapons_added[player_index]:
		for weapon in ItemService.weapons:
			var weapon_to_add = weapon
			if curse_debug_items_and_weapons:
				weapon_to_add = ProgressData.available_dlcs[0].curse_item(weapon, player_index)
			var _added_weapon = RunData.add_weapon(weapon_to_add, player_index)
		debug_weapons_added[player_index] = true

	if add_all_items and not debug_items_added[player_index]:
		for item in ItemService.items:
			if item.my_id == "item_axolotl":
				continue
			var item_to_add = item
			if curse_debug_items_and_weapons:
				item_to_add = ProgressData.available_dlcs[0].curse_item(item, player_index)
			RunData.add_item(item_to_add, player_index)
		debug_items_added[player_index] = true

	if debug_weapons.size() > 0 and not debug_weapons_added[player_index]:
		for weapon in debug_weapons:
			var weapon_to_add = weapon
			if curse_debug_items_and_weapons:
				weapon_to_add = ProgressData.available_dlcs[0].curse_item(weapon, player_index)
			var _added_weapon = RunData.add_weapon(weapon_to_add, player_index)
		debug_weapons_added[player_index] = true

	if debug_items.size() > 0 and not debug_items_added[player_index]:
		for item in debug_items:
			var item_to_add = item
			if curse_debug_items_and_weapons:
				item_to_add = ProgressData.available_dlcs[0].curse_item(item, player_index)
			RunData.add_item(item_to_add, player_index)
		debug_items_added[player_index] = true


func _randomize_equipement(player_index) -> void :
	RunData.remove_all_weapons(player_index)
	var weapon = Utils.get_rand_element(ItemService.weapons)
	for _i in range(6):
		var weapon_to_add = weapon
		if curse_debug_items_and_weapons:
			weapon_to_add = ProgressData.available_dlcs[0].curse_item(weapon, player_index)
		var _weapon = RunData.add_weapon(weapon_to_add, player_index)

	for old_items in RunData.players_data[player_index].items:
		RunData.remove_item(old_items, player_index)
	for i in 10:
		var item = Utils.get_rand_element(ItemService.items).duplicate()
		if curse_debug_items_and_weapons:
			item = ProgressData.available_dlcs[0].curse_item(item, player_index)
		RunData.add_item(item, player_index)

	for i in 30:
		var upg = Utils.get_rand_element(ItemService.upgrades)
		RunData.add_item(upg, player_index)


func log_run_info(upgrades: Array = [[], [], [], []], consumables: Array = [[], [], [], []]) -> void :
	if OS.get_name().begins_with("Seaven"):
		return

	var log_file = FileAccess.open(ProgressData.LOG_PATH, FileAccess.READ_WRITE)
	var error = OK if log_file != null else FileAccess.get_open_error()

	if error != OK:
		printerr("Could not open the file %s. Aborting save operation. Error code: %s" %
		[ProgressData.LOG_PATH, error])
		return

	log_file.seek_end()
	log_file.store_line("--Run Data--")
	for player_index in RunData.get_player_count():
		log_file.store_line("** Player %s" % player_index)
		log_file.store_line("Character: " + str(RunData.get_player_character(player_index).my_id))
		log_file.store_line("Wave: " + str(RunData.current_wave))
		log_file.store_line("Danger: " + str(RunData.current_difficulty))
		log_file.store_line("Level ups: " + str(upgrades[player_index].size()))
		log_file.store_line("Consumables: " + str(consumables[player_index].size()))
		log_file.store_line("Gold: " + str(RunData.get_player_gold(player_index)))
		log_file.store_line("Bonus Gold: " + str(RunData.bonus_gold))

		var items = ""

		for item in RunData.get_player_items(player_index):
			items += item.my_id + ", "

		log_file.store_line("Items: " + str(items))

		var weapons = ""

		for item in RunData.get_player_weapons_ref(player_index):
			weapons += item.my_id + ", "

		log_file.store_line("Weapons: " + str(weapons))

	log_file.store_line("--Run Data end--")
	log_file.close()


func log_data(text: String) -> void :
	if OS.get_name().begins_with("Seaven"):
		return

	var log_file = FileAccess.open(ProgressData.LOG_PATH, FileAccess.READ_WRITE)
	var error = OK if log_file != null else FileAccess.get_open_error()

	if error != OK:
		printerr("Could not open the file %s. Aborting save operation. Error code: %s" %
		[ProgressData.LOG_PATH, error])
		return

	log_file.seek_end()
	log_file.store_line(text)
	log_file.close()
