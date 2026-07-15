class_name _ModLoaderSteam
extends Node

const LOG_NAME: = "ModLoader:ThirdParty:Steam"







static func load_steam_workshop_zips() -> Dictionary:
	var zip_data: = {}
	var workshop_folder_path: = _get_path_to_workshop()

	ModLoaderLog.info("Checking workshop items, with path: \"%s\"" % workshop_folder_path, LOG_NAME)

	var workshop_dir := DirAccess.open(workshop_folder_path)
	var workshop_dir_open_error: int = OK if workshop_dir != null else DirAccess.get_open_error()
	if not workshop_dir_open_error == OK:
		ModLoaderLog.error("Can't open workshop folder %s (Error: %s)" % [workshop_folder_path, workshop_dir_open_error], LOG_NAME)
		return {}
	var workshop_dir_listdir_error: int = workshop_dir.list_dir_begin()
	if not workshop_dir_listdir_error == OK:
		ModLoaderLog.error("Can't read workshop folder %s (Error: %s)" % [workshop_folder_path, workshop_dir_listdir_error], LOG_NAME)
		return {}

	var subscribed_items: = Platform.get_subscribed_mods()

	
	while true:

		var item_dir: String = workshop_dir.get_next()
		var item_path: String = workshop_dir.get_current_dir() + "/" + item_dir

		ModLoaderLog.info("Checking workshop item path: \"%s\"" % item_path, LOG_NAME)

		
		if item_dir == "":
			break

		
		if not workshop_dir.current_is_dir():
			continue

		if int(item_dir) in subscribed_items:
			
			zip_data.merge(_ModLoaderFile.load_zips_in_folder(ProjectSettings.globalize_path(item_path)))

	workshop_dir.list_dir_end()

	return zip_data











static func _get_path_to_workshop() -> String:
	if ModLoaderStore.ml_options.override_path_to_workshop:
		return ModLoaderStore.ml_options.override_path_to_workshop

	var game_install_directory: = _ModLoaderPath.get_local_folder_dir()
	var path: = ""

	
	var path_array: = game_install_directory.split("/")
	path_array.resize(path_array.size() - 3)

	
	path = "/".join(path_array)

	
	path = path.path_join("workshop/content/" + _get_steam_app_id())

	return path






static func _get_steam_app_id() -> String:
	var game_install_directory: = _ModLoaderPath.get_local_folder_dir()
	var steam_app_id: = ""
	var file := FileAccess.open(game_install_directory.path_join("steam_data.json"), FileAccess.READ)

	if file != null:
		var test_json_conv = JSON.new()
		test_json_conv.parse(file.get_as_text())
		var file_content: Dictionary = test_json_conv.get_data()
		file.close()

		if not file_content.has("app_id"):
			ModLoaderLog.error("The steam_data file does not contain an app ID. Mod uploading will not work.", LOG_NAME)
			return ""

		steam_app_id = file_content.app_id
	else:
		ModLoaderLog.error("Can't open steam_data file, \"%s\". Please make sure the file exists and is valid." % game_install_directory.path_join("steam_data.json"), LOG_NAME)

	return steam_app_id
