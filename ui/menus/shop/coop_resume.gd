extends Control


var _players_to_join: = []

@onready var _progress_bar: UIProgressBar = $"%UIProgressBar"
@onready var _player_label = $"%CoopPlayerLabel"
@onready var _player_info_container = $"%PlayerInfoContainer"
@onready var _gold_icon = $"%GoldIcon"
@onready var _gold_label = $"%GoldLabel"
@onready var _player_gear_container = $"%PlayerGearContainer"

var __need_controller_applet_timer = - 1


@export var ps_device_colors: = [ # (Array, int)
	4278767051, 
	4290910731, 
	4281319940, 
	4290953728
]

func set_controller_colors() -> void :
	if RunData.play_mode == RunData.PlayMode.COOP and Utils.on_playstation:
		for player_index in CoopService.get_max_players():
			var device = CoopService.get_remapped_player_device(player_index)
			if device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID:
				device = 0
			if device >= 0 and device < 4:
				OS_Seaven.set_controller_color(device, ps_device_colors[player_index])

func _ready() -> void :
	_progress_bar.modulate.a = 0.0
	CoopService.listening_for_inputs = true
	for player_index in RunData.get_player_count():
		_players_to_join.push_back(player_index)
	
	var _error = CoopService.connect("connected_players_updated", Callable(self, "_on_connected_players_updated"))
	_error = CoopService.connect("connection_progress_updated", Callable(self, "_on_connection_progress_updated"))
	_setup_next_player()
	CoopService.set_process_input(true)
	if Utils.on_nintendo_nx_or_ounce:
		if RunData.play_mode == RunData.PlayMode.COOP:
			print("[CoopResume] Coop")
			print("[CoopResume] max controller ", RunData.get_player_count())
			OS_Seaven.set_max_controller_count(RunData.get_player_count())
			OS_Seaven.set_controller_color(0, 4293786785)
			OS_Seaven.set_controller_color(1, 4287081970)
			OS_Seaven.set_controller_color(2, 4288806057)
			OS_Seaven.set_controller_color(3, 4287623420)
			set_process(true)
			__need_controller_applet_timer = 1

	set_controller_colors()


func _exit_tree() -> void :
	CoopService.set_process_input(false)


func _input(event: InputEvent) -> void :
	if event.is_action_released("ui_cancel"):
		var _error = get_tree().change_scene_to_file(MenuData.title_screen_scene)


func _setup_next_player() -> void :
	print("setup next players  left " + str(len(_players_to_join)))
	if _players_to_join.is_empty():
		print("go to coop shop")
		CoopService.listening_for_inputs = false
		
		if Utils.on_nintendo_nx_or_ounce:
			OS_Seaven.set_fast_cpu_mode(true)
		var _error = get_tree().change_scene_to_file("res://ui/menus/shop/coop_shop.tscn")
		if Utils.on_nintendo_nx_or_ounce:
			OS_Seaven.set_fast_cpu_mode(false)
		return

	var player_index = _players_to_join.pop_front()
	_update_player_index(player_index)
	set_controller_colors()


func _update_player_index(player_index: int) -> void :
	_player_label.player_index = player_index
	var items = RunData.get_player_items(player_index)
	var weapons = RunData.get_player_weapons(player_index)
	_player_gear_container.set_items_data(items)
	_player_gear_container.set_weapons_data(weapons)
	_gold_label.update_value(RunData.get_player_gold(player_index))

	var player_color = CoopService.get_player_color(player_index)
	_gold_icon.modulate = player_color
	_gold_label.add_theme_color_override("font_color", player_color)

	var stylebox = _player_info_container.get_theme_stylebox("panel").duplicate()
	CoopService.change_stylebox_for_player(stylebox, player_index)
	_player_info_container.add_theme_stylebox_override("panel", stylebox)


func _on_connected_players_updated(_connected_players: Array) -> void :
	_setup_next_player()


func _on_connection_progress_updated(connection_progress: Array) -> void :
	var progress = 0.0 if connection_progress.is_empty() else connection_progress.front()
	_progress_bar.modulate.a = 1.0 if progress > 0.0 else 0.0
	_progress_bar.value = progress


func _process(_delta: float) -> void :
	if RunData.is_coop_run and Utils.on_nintendo_nx_or_ounce:
		
		var num_connected_players = RunData.get_player_count()
		if OS_Seaven.get_controller_count() != num_connected_players:
			if __need_controller_applet_timer >= 0:
				__need_controller_applet_timer -= 1
				if __need_controller_applet_timer < 0:
					__need_controller_applet_timer = - 1
					print("[CoopResume] show controller applet in process")
					if not OS_Seaven.show_controller_applet(num_connected_players, num_connected_players):
						var _error = get_tree().change_scene_to_file(MenuData.title_screen_scene)
						OS_Seaven.set_max_controller_count(1)
						OS_Seaven.show_controller_applet(1, 1)
				return

		else:
			
			for i in OS_Seaven.get_controller_count():
				var remapped = i
				if remapped == 0:
					remapped = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
				CoopService._add_player(remapped, CoopService.PlayerType.GAMEPAD_SWITCH)
	return
