class_name SteamPlatform
extends AbstractPlatform

var steam

var quit_game: = false
var init_error: = false
var steam_id: = 0


var steam_languages_map = {
	"english": "en", 
	"french": "fr", 
	"schinese": "zh", 
	"tchinese": "zh_TW", 
	"japanese": "ja", 
	"koreana": "ko", 
	"russian": "ru", 
	"polish": "pl", 
	"spanish": "es", 
	"brazilian": "pt", 
	"german": "de", 
	"turkish": "tr", 
	"italian": "it"
}

var steam_app_id_mapping: = {
	"base": 1942280, 
	"abyssal_terrors": 2868390, 
}


func _init() -> void :
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")

	if steam.restartAppIfNecessary(steam_app_id_mapping["base"]):
		print("Restarting game over Steam...")
		quit_game = true
		return

	var init_result: Dictionary = steam.steamInitEx(steam_app_id_mapping["base"], true)
	prints("Steam initialization:", init_result)

	if init_result.status != 0:
		printerr("Steam initialization failed. Please check if Steam is running. Continuing without Steam...")
		init_error = true
		return

	if not steam.isSubscribed():
		printerr("Not owned on Steam: Shutting down")
		quit_game = true
		return

	prints("steam_is_online:", steam.loggedOn())
	steam_id = steam.getSteamID()
	prints("steam_id:", steam_id)
	prints("steam_is_owned:", steam.isSubscribed())


func _enter_tree():
	if quit_game:
		# 4.x 移植: 3.x 靠向 SceneTree 发 WM_QUIT_REQUEST 通知退出，4.x SceneTree 不再响应该通知
		get_tree().quit()


func get_type() -> int:
	return PlatformType.STEAM


func get_user_id() -> String:
	if steam_id != 0:
		return str(steam_id)
	else:
		return "user"


func get_language() -> String:
	if init_error:
		return "en"

	var steam_lang = steam.getCurrentGameLanguage()

	if steam_lang != "None" and steam_languages_map.has(steam_lang):
		return steam_languages_map.get(steam_lang)

	return "en"


func is_dlc_owned(dlc_my_id: String) -> bool:
	if init_error:
		return true

	var steam_app_id: int = steam_app_id_mapping.get(dlc_my_id)
	if steam_app_id != null:
		return steam.isDLCInstalled(steam_app_id)

	else:
		print("DLC installed check for %s failed" % dlc_my_id)
		return false


func is_challenge_completed(chal_id: String) -> bool:
	if init_error:
		return false

	return steam.getAchievement(chal_id).achieved


func complete_challenge(chal_id: int) -> void :
	if init_error:
		return

	var steam_achievement = steam.getAchievement(Keys.hash_to_string[chal_id])
	if not steam_achievement.achieved:
		var _achievement = steam.setAchievement(Keys.hash_to_string[chal_id])
		var _stored = steam.storeStats()


func reinitialize_store_data() -> void :
	print("steam reset data")
	var _reset = steam.resetAllStats(true)


func open_store_page(url: String) -> void :
	if init_error:
		var _error: = OS.shell_open(url)

	steam.activateGameOverlayToWebPage(url, 0)


func open_mods_page() -> void :
	var url: = "https://steamcommunity.com/app/1942280/workshop/"
	if init_error:
		var _error: = OS.shell_open(url)
	steam.activateGameOverlayToWebPage(url, 0)


func get_dlc_url() -> String:
	return "https://store.steampowered.com/app/2868390"


func get_more_games_url() -> String:
	return "https://www.blobfishgames.com/games"


func get_subscribed_mods() -> Array:
	if init_error:
		return []

	return steam.getSubscribedItems()
