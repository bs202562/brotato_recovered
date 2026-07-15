class_name PauseMenu
extends PanelContainer

signal paused
signal unpaused


var _player_index: = 0
var enabled: = true

@onready var _main_menu = $Menus / MainMenu
@onready var _menus = $Menus
@onready var _menu_options = $Menus / MenuOptions
@onready var _focus_emulator: FocusEmulator = $FocusEmulator

var codex_is_opened: = false

func _ready() -> void :
	var _error = _main_menu.connect("resume_button_pressed", Callable(self, "on_resume_button_pressed"))
	_error = _main_menu.connect("codex_button_pressed", Callable(self, "on_codex_button_pressed"))
	_error = _menus.connect("codex_closed", Callable(self, "on_codex_closed"))
	_focus_emulator.player_index = - 1
	set_process_input(false)
	_focus_emulator.set_process_input(false)


func init() -> void :
	_player_index = 0
	_main_menu.init(0)


func _input(event: InputEvent) -> void :
	if get_tree().paused:
		if Utils.is_player_cancel_released(event, _player_index) or Utils.is_player_pause_released(event, _player_index):
			if codex_is_opened:
				return
			manage_back()
			get_viewport().set_input_as_handled()
		return

	if RunData.is_streamplay_run:
		if Utils.is_player_pause_released(event, 0):
				_player_index = 0
				pause(0)
	else:
		for player_index in RunData.get_player_count():
			if Utils.is_player_pause_released(event, player_index):
				_player_index = player_index
				pause(player_index)
				break


func manage_back() -> void :
	if _main_menu.visible:
		unpause()
	else:
		_menus.back()

func unpause() -> void :
	
	if RunData.is_coop_run and not RunData.is_streamplay_run and Utils.on_nintendo_nx_or_ounce:
		print("Check player count before unpause")
		if OS_Seaven.get_controller_count() != RunData.get_player_count():
			print("Controller count different from player count, show applet " + str(OS_Seaven.get_controller_count()) + " " + str(RunData.get_player_count()))
			OS_Seaven.show_controller_applet(RunData.get_player_count(), RunData.get_player_count())
			return

	set_process_input(false)
	_focus_emulator.set_process_input(false)
	_focus_emulator.player_index = - 1
	hide()
	get_tree().paused = false
	_menus.reset()
	emit_signal("unpaused")


func pause(player_index: int) -> void :
	set_process_input(true)
	_focus_emulator.set_process_input(true)
	if not enabled:
		return
	_player_index = player_index
	_focus_emulator.player_index = player_index
	
	
	get_tree().paused = true
	emit_signal("paused")
	show()
	Utils.set_default_cursor()
	_main_menu.init(player_index)


func on_resume_button_pressed() -> void :
	unpause()

func on_codex_button_pressed() -> void :
	codex_is_opened = true

func on_codex_closed() -> void :
	codex_is_opened = false

func on_game_lost_focus() -> void :
	if not get_tree().paused and ProgressData.settings.pause_on_focus_lost:
		_player_index = 0
		pause(0)

	if get_tree().paused:
		if RunData.is_coop_run and _player_index > 0 and OS_Seaven.get_controller_count() != RunData.get_player_count():
			print("Change pause ownership to player 0")
			_player_index = 0
			_focus_emulator.player_index = 0
			_menus.reset()
			_main_menu.init(0)
