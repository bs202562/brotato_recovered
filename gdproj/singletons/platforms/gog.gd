class_name GOGPlatform
extends AbstractPlatform

var gog
var initialized: = false
var init_success: = false

var user_id: String

var gog_id_mapping: = {
	"base": 1118951034, 
	"abyssal_terrors": 1562256538, 
}

func _ready():
	if OS.get_name() == "X11":
		initialized = true
		init_success = false
		return

	gog = load("res://addons/gog_bindings/gog_bindings.gdns").new()
	add_child(gog)
	var _e = gog.connect("init_finished", self, "_on_init_finished")
	gog.client_id = "59334299015044628"
	gog.client_secret = "2a927e31396fd0790a4552419a1c9728226387146428570f8c667822411e3f0f"

	gog.initialize()


func _on_init_finished(success: bool) -> void :
	initialized = true
	init_success = success


func get_type() -> int:
	return PlatformType.GOG


func get_user_id() -> String:
	return "GOG-Saves"


func is_challenge_completed(chal_id: String) -> bool:
	if not initialized:
		yield(gog, "init_finished")
	if init_success:
		return gog.is_achievement_unlocked(chal_id)
	return false


func complete_challenge(chal_id: int) -> void :
	if not initialized:
		yield(gog, "init_finished")
	if init_success and not gog.is_achievement_unlocked(Keys.hash_to_string[chal_id]):
		gog.unlock_achievement(Keys.hash_to_string[chal_id])


func is_dlc_owned(_dlc_my_id: String) -> bool:
	return true


func get_language() -> String:
	return OS.get_locale_language()


func reinitialize_store_data() -> void :
	if not initialized:
		yield(gog, "init_finished")
	if init_success:
		gog.reset_stats_and_achievements()


func open_store_page(url: String) -> void :
	OS.shell_open(url)


func open_mods_page() -> void :
	return


func get_dlc_url() -> String:
	return "https://www.gog.com/game/brotato_abyssal_terrors"


func get_more_games_url() -> String:
	return "https://blobfishgames.com/#about"
