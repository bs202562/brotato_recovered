class_name TitleScreenMenus
extends Menus

onready var _menu_credits = $MenuCredits
onready var _menu_mods = $MenuMods
onready var _profile_scene = $MenuProfile


func _on_MainMenu_credits_button_pressed() -> void :
	switch(_main_menu, _menu_credits)


func _on_MenuCredits_back_button_pressed() -> void :
	switch(_menu_credits, _main_menu)

func _on_MainMenu_mods_button_pressed() -> void :
	switch(_main_menu, _menu_mods)


func _on_MenuMods_back_button_pressed() -> void :
	switch(_menu_mods, _main_menu)


func _on_MainMenu_profile_button_pressed():
	switch(_main_menu, _profile_scene)


func _on_MenuProfile_back_button_pressed():
	switch(_profile_scene, _main_menu)
