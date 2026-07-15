class_name TitleScreen
extends Control

onready var _menus: Control = $"%Menus"
onready var _main_menu: VBoxContainer = $"%MainMenu"
onready var _animated_background_container: Control = $"%AnimatedBackgroundContainer"
onready var _attenuate_background: ColorRect = $"%AttenuateBackground"
onready var _pop_up_mods_update_warning: PopupAnouncement = $"%popup_mods_update_warning"
onready var _pop_up_beta_save_warning: PopupAnouncement = $"%popup_beta_save_warning"

var current_keyart: TitleScreenBackgroundData

func _ready() -> void :

	var _e = ProgressData.connect("dlc_activated", self, "on_dlc_changed")
	_e = ProgressData.connect("dlc_deactivated", self, "on_dlc_changed")

	ProgressData.connect("change_keyart", self, "reload_background")

	reload_background()
	update_continue_button()
	update_profile_button()

	if not Utils.is_on_console() or Utils.on_gdk_desktop:
		_main_menu.quit_button.show()
		_main_menu.quit_button.activate()
	else:
		_main_menu.quit_button.hide()
		_main_menu.quit_button.disable()

	RunData.current_zone = 0
	RunData.reset()

	if RunData.reload_music:
		MusicManager.play(0)
	else:
		RunData.reload_music = true

	var _switched_result: = _menus.connect("menu_page_switched", self, "on_menu_page_switched")
	_main_menu.init()
	if Utils.on_nintendo_nx_or_ounce and OS_Seaven.get_max_controller_count() > 1:
		OS_Seaven.set_max_controller_count(1)
		OS_Seaven.show_controller_applet(1, 1)

	if ProgressData.should_show_mod_warning_popup():
		_pop_up_mods_update_warning.popup()

	if ProgressData.show_main_title_beta_save_warning_popup:
		_pop_up_beta_save_warning.popup()


func on_dlc_changed(_dlc_id: String) -> void :
	reload_background()

func update_continue_button():
	if ProgressData.saved_run_state.has_run_state and ProgressData.check_dlc_valid_for_saved_run_state() and not ProgressData.saved_run_state.get("is_streamplay_run", false):
		_main_menu.continue_button.show()
		_main_menu.continue_button.activate()
	else:
		_main_menu.continue_button.hide()
		_main_menu.continue_button.disable()

func update_profile_button():
	_main_menu.profile_button.text = Text.text("MENU_PROFILE", [str(ProgressData.current_profile_id + 1)])

func sort_by_priority(a, b):
	return a.index_priority < b.index_priority

func reload_background() -> void :
	for child in _animated_background_container.get_children():
		child.queue_free()

	var key_art_mode: int = ProgressData.settings.main_screen_keyart
	if key_art_mode - 2 >= ItemService.title_screen_backgrounds.size():
		key_art_mode = 0

	match key_art_mode:
		0:
			ItemService.title_screen_backgrounds.sort_custom(self, "sort_by_priority")
			for i in range(ItemService.title_screen_backgrounds.size() - 1, - 1, - 1):
				var screen = ItemService.title_screen_backgrounds[i]
				if screen.is_available():
					current_keyart = screen
					break
		1:
			current_keyart = ItemService.title_screen_backgrounds.pick_random()
		_:
			current_keyart = ItemService.title_screen_backgrounds[key_art_mode - 2]

	var instance = current_keyart.scene.instance()
	_animated_background_container.add_child(instance)
	_main_menu.reload_logo(current_keyart)


func on_menu_page_switched(_from: Control, to: Control) -> void :
	if to != _main_menu:
		_attenuate_background.show()
	else:
		_attenuate_background.hide()
		update_continue_button()
		update_profile_button()

