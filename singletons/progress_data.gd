## 全局单例 ProgressData:跨局持久化数据的总管家。
## 职责:存档加载/保存(实际序列化委托给 ProgressDataLoaderV1/V2/V3/Beta)、
## 设置系统(settings.json)、解锁进度(角色/武器/物品/难度)、3 个存档位管理、
## DLC 加载与开关、统计数据、平台活动(PS5 Activity)。
## 与之相对,RunData 只保存当前一局的运行时状态。
extends Node

signal dlc_activated(dlc_id) # DLC 激活且资源已注册后发出
signal dlc_deactivated(dlc_id) # DLC 停用且资源已移除后发出
signal language_changed() # change_language() 切换语言后发出
signal change_keyart() # 主界面主视觉图切换时发出

const VERSION = "1.1.15.4" # 当前游戏版本,写入设置用于版本迁移判断
const BETA = false # 为真时全程改用 ProgressDataLoaderBeta 读写存档
const VERSION_SWITCH = "1.1.13.2" # Switch 平台专用版本号

const DLC_1_APP_ID = 2868390 # DLC1(Abyssal Terrors)的 Steam AppID

var smallest_text_font = preload("res://resources/fonts/actual/base/font_smallest_text.tres") # 最小号文字字体(字号缩放基准)

# 支持的语言列表(设置页选项与 change_language 校验)
var languages = [
	"en", "fr", "zh", "zh_TW", "ja", "ko", "ru", "pl", "es", "pt", "de", "tr", "it"
]

var current_profile_id: = 0 # 当前使用的存档位
var profile_count: = 3 # 存档位数量
const SETTINGS_FILE_NAME: = "/settings.json" # 设置文件名(位于 SAVE_DIR 下)

const MAX_DIFFICULTY: = 6 # 可选危险度上限
const SMALLEST_FONT_BASE_SIZE: = 21 # 最小字体的基准字号
const FPS_LIMIT: = 60 # limit_fps 开启时的帧率上限

# 六档物品品质默认颜色(白/蓝/紫/红/橙/黄),无障碍自定义颜色的默认值
const DEFAULT_TIER_COLOR_0 = Color(230.0 / 255, 230.0 / 255, 230.0 / 255, 1)
const DEFAULT_TIER_COLOR_1 = Color(90.0 / 255, 190.0 / 255, 255.0 / 255, 1)
const DEFAULT_TIER_COLOR_2 = Color(173.0 / 255, 90.0 / 255, 255.0 / 255, 1)
const DEFAULT_TIER_COLOR_3 = Color(255.0 / 255, 59.0 / 255, 59.0 / 255, 1)
const DEFAULT_TIER_COLOR_4 = Color(255.0 / 255, 119.0 / 255, 59.0 / 255, 1)
const DEFAULT_TIER_COLOR_5 = Color(208.0 / 255, 193.0 / 255, 66.0 / 255, 1)

var SAVE_DIR: = "" # 存档目录:user:// + 平台用户 ID,init_save_paths() 中确定
var SAVE_PATH: = "" # 当前档位存档文件的完整路径
var LOG_PATH: = "" # 日志文件路径
var fallback_dir_name: String = "user" # 旧版存档目录名,首次运行时从中迁移

var activity_started: bool = false # 当前是否有进行中的 PSN 活动
var need_activity: bool = false # 是否启用活动系统(仅 PS5)
var need_activity_reset: bool = true # 启动后是否需要清理一次残留活动


var load_status = LoadStatus.SAVE_OK # 最近一次存档加载的结果状态

var available_dlcs: = [] # 可用的 DLCData 列表(已安装且拥有)

# 解锁进度数组。除 zones_unlocked 存明文 ID 外,其余存的都是 ID 的哈希值
# (my_id_hash),写盘时经 Utils.convert_to_hash_array 统一转换
var zones_unlocked: = []
var characters_unlocked: = []

var upgrades_unlocked: = []
var consumables_unlocked: = []

var weapons_unlocked: = []
var items_unlocked: = []
var challenges_completed: = []
var systems_unlocked: = []

var difficulties_unlocked: = [] # CharacterDifficultyInfo 数组:角色 × 地图的难度进度
var inactive_mods: = [] # 玩家停用的 Mod 列表

var read_announcements: = [] # 已读公告 ID

var show_main_title_mod_warning_popup: = false # 版本跨越且装了 Mod 时主菜单弹兼容警告
var show_main_title_beta_save_warning_popup: = false # Beta 存档警告弹窗标记

var saved_run_state: Dictionary # 中途退出保存的整局快照("继续游戏"数据源)
var last_saved_run_state: Dictionary # 本次会话内最后一次保存的快照
var settings: Dictionary = {} # 玩家设置(独立存于 settings.json)
var data: Dictionary = {} # 通用统计计数器,键见 get_fresh_data()
var killed_enemies: Dictionary = {} # 敌人哈希 → 击杀数(图鉴解锁)
var killed_by_enemies: Dictionary = {} # 敌人哈希 → 被其击杀次数
var items_bought: Dictionary = {} # 物品/武器哈希 → 购买次数(图鉴点亮)

# ---------- PS5 Activity(PSN 活动卡片)封装,仅 need_activity 为真时生效 ----------

## 开始一段 PSN 活动(进入一局游戏时调用)
func start_activity() -> void :
	if need_activity:
		activity_started = true
		print("start_activity")
		OS_Seaven.start_activity("Activity1")

## 启动后首次调用时清理上次异常退出残留的活动状态(只执行一次)
func reset_activity() -> void :
	if need_activity_reset:
		need_activity_reset = false
		terminate_activity()

## 中止活动(不上报成败,如中途退出)
func terminate_activity() -> void :
	if need_activity:
		activity_started = false
		print("terminate_activity")
		OS_Seaven.terminate_activity("Activity1")

## 结束活动并上报成败结果(一局胜利/失败时)
func end_activity(completed: bool) -> void :
	if need_activity:
		activity_started = false
		print("end_activity with " + str(completed))
		OS_Seaven.end_activity("Activity1", completed)

func is_activity_started() -> bool:
	if need_activity:
		return activity_started
	else:
		return false

## 获取系统侧待处理的活动 ID(玩家从 PSN 活动卡片启动游戏时非空)
func get_pending_activity() -> String:
	if need_activity:
		return OS_Seaven.get_pending_activity()
	else:
		return ""

## 主机平台:系统侧是否有 DLC 安装/卸载变更待处理
func get_pending_dlc_change() -> bool:
	if Utils.is_on_console():
		return OS_Seaven.has_dlc_updates();
	return false

## 启动入口,顺序严格:
## 1. 初始化存档路径 → 2. 加载 DLC pck → 3. 扫描可用 DLC
## 4. 默认设置 + 读盘覆盖 + 版本检查 → 5. 初始化统计与空局快照
## 6. 注册 DLC 资源 → 7. 加载存档并补默认解锁 → 8. 移除玩家停用的 DLC 资源
func _ready() -> void :
	init_save_paths()
	load_dlc_pcks()
	check_for_available_dlcs()

	init_settings()
	load_settings()
	check_settings_version()

	init_data()
	randomize()
	saved_run_state = _get_empty_run_state()

	
	for available_dlc in available_dlcs:
		available_dlc.add_resources()

	RunData.reset()

	if DebugService.generate_full_unlocked_save_file:
		unlock_all()
		save()
	else:
		load_game_file()
		add_unlocked_by_default()

	set_max_selectable_difficulty()

	for available_dlc in available_dlcs:
		if settings.deactivated_dlcs.has(available_dlc.my_id) or get_tree().current_scene.name == "GutRunner":
			available_dlc.remove_resources()

	if Utils.on_ps5:
		print("PS5 platform : activate activity")
		need_activity = true


## 构造默认设置字典(随后由 load_settings() 用磁盘值合并覆盖)
func init_settings() -> void :
	settings = {"version": VERSION, "endless_mode_toggled": false, "play_mode": RunData.PlayMode.SOLO, "ban_mode_toggled": true, "zone_selected": 0, "zone_is_random": false}
	settings.merge(init_general_options())
	settings.merge(init_gameplay_options())
	settings.merge(init_accessibilities_options())
	settings.language = Platform.get_language()

## 存档设置版本与当前不一致时更新版本号;前三段版本号有变则标记弹 Mod 兼容警告
func check_settings_version() -> void :
	if settings["version"] == VERSION:
		return

	var old_version = settings["version"]
	if are_major_versions_different(old_version, VERSION):
		show_main_title_mod_warning_popup = true

	settings["version"] = VERSION

## 比较两个版本号的前三段(major.minor.patch)是否不同;格式非法视为不同
func are_major_versions_different(v1: String, v2: String) -> bool:
	var a = v1.split(".")
	var b = v2.split(".")

	
	if a.size() < 3 or b.size() < 3:
		push_error("Invalid version format")
		return true

	for i in range(3):
		if int(a[i]) != int(b[i]):
			return true

	return false

## 仅当版本跨越且实际装了 Mod 时才需要弹兼容警告
func should_show_mod_warning_popup() -> bool:
	return show_main_title_mod_warning_popup and ModLoaderMod.get_mod_data_all().size() > 0


func init_data() -> void :
	data = get_fresh_data()


## 全新的统计计数器字典;这些键被成就/挑战判定引用
func get_fresh_data() -> Dictionary:
	return {
		"fruit_eaten_full_hp": 0, 
		"chal_hourglass_quit_wave": 0, 
		"is_unlock_all_save": 0, 
		"run_won": 0, 
		"run_started": 0, 
		"enemies_killed": 0, 
		"materials_collected": 0, 
		"trees_killed": 0, 
		"steps_taken": 0, 
		"enemies_killed_far_away": 0, 
		"evil_mob_killed": 0, 
		"evil_mob_killed_by": 0
	}


## 清空内存中的全部进度(切换档位前调用),并补回默认解锁
func reset() -> void :
	saved_run_state = _get_empty_run_state()
	zones_unlocked.clear()
	characters_unlocked.clear()
	upgrades_unlocked.clear()
	consumables_unlocked.clear()
	weapons_unlocked.clear()
	items_unlocked.clear()
	challenges_completed.clear()
	difficulties_unlocked.clear()
	init_data()
	killed_enemies.clear()
	killed_by_enemies.clear()
	items_bought.clear()
	add_unlocked_by_default()

## 将指定档位重置为空档(仅默认解锁)并落盘;若是当前档位则同步回内存
func reset_save_profile(id: int) -> void :
	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, id)
		loader_beta.add_unlocked_by_default_from_blank_save()
		loader_beta.run_state_deserialized = _get_empty_run_state()
		loader_beta.save()
		if current_profile_id == id:
			load_with_generic_loader(loader_beta)
	else:
		var loader = ProgressDataLoaderV3.new(SAVE_DIR, id)
		loader.add_unlocked_by_default_from_blank_save()
		loader.run_state_deserialized = _get_empty_run_state()
		loader.save()
		if current_profile_id == id:
			load_with_generic_loader(loader)

## 将指定档位全解锁并落盘;若是当前档位则同步回内存
func unlock_all_save_profile(id: int) -> void :
	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, id)
		loader_beta.load_game_file()
		loader_beta.unlock_all()
		loader_beta.run_state_deserialized = _get_empty_run_state()
		loader_beta.save()
		if current_profile_id == id:
			load_with_generic_loader(loader_beta)
	else:
		var loader = ProgressDataLoaderV3.new(SAVE_DIR, id)
		loader.load_game_file()
		loader.unlock_all()
		loader.run_state_deserialized = _get_empty_run_state()
		loader.save()
		if current_profile_id == id:
			load_with_generic_loader(loader)

## 当前存档是否由"全解锁"功能生成(用于区分正常进度)
func is_unlock_all_save() -> bool:
	if data.has("is_unlock_all_save"):
		return data.is_unlock_all_save == 1
	return false

## 档位复制:源档位读盘后逐字段 duplicate 到目标档位再落盘;
## 目标是当前档位则同步回内存
func copy_save_profile(from_id: int, to_id: int) -> void :
	if BETA:
		var from_loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, from_id)
		from_loader_beta.load_game_file()
		if from_loader_beta.load_status != LoadStatus.SAVE_OK:
			printerr("Could not copy save profile from id %s because it could not be loaded" % from_id)
			return

		var to_loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, to_id)
		to_loader_beta.zones_unlocked = from_loader_beta.zones_unlocked.duplicate()
		to_loader_beta.characters_unlocked = from_loader_beta.characters_unlocked.duplicate()
		to_loader_beta.upgrades_unlocked = from_loader_beta.upgrades_unlocked.duplicate()
		to_loader_beta.consumables_unlocked = from_loader_beta.consumables_unlocked.duplicate()
		to_loader_beta.weapons_unlocked = from_loader_beta.weapons_unlocked.duplicate()
		to_loader_beta.items_unlocked = from_loader_beta.items_unlocked.duplicate()
		to_loader_beta.challenges_completed = from_loader_beta.challenges_completed.duplicate()
		to_loader_beta.difficulties_unlocked_serialized.clear()
		for difficulty_unlocked in from_loader_beta.difficulties_unlocked_serialized:
			to_loader_beta.difficulties_unlocked_serialized.push_back(difficulty_unlocked)
		to_loader_beta.inactive_mods = from_loader_beta.inactive_mods.duplicate()
		to_loader_beta.read_announcements = from_loader_beta.read_announcements.duplicate()
		to_loader_beta.run_state_deserialized = from_loader_beta.run_state_deserialized.duplicate()
		to_loader_beta.data = from_loader_beta.data.duplicate()
		to_loader_beta.killed_enemies = from_loader_beta.killed_enemies.duplicate()
		to_loader_beta.killed_by_enemies = from_loader_beta.killed_by_enemies.duplicate()
		to_loader_beta.items_bought = from_loader_beta.items_bought.duplicate()
		to_loader_beta.save()

		if current_profile_id == to_id:
			load_with_generic_loader(to_loader_beta)
	else:
		var from_loader = ProgressDataLoaderV3.new(SAVE_DIR, from_id)
		from_loader.load_game_file()
		if from_loader.load_status != LoadStatus.SAVE_OK:
			printerr("Could not copy save profile from id %s because it could not be loaded" % from_id)
			return

		var to_loader = ProgressDataLoaderV3.new(SAVE_DIR, to_id)
		to_loader.zones_unlocked = from_loader.zones_unlocked.duplicate()
		to_loader.characters_unlocked = from_loader.characters_unlocked.duplicate()
		to_loader.upgrades_unlocked = from_loader.upgrades_unlocked.duplicate()
		to_loader.consumables_unlocked = from_loader.consumables_unlocked.duplicate()
		to_loader.weapons_unlocked = from_loader.weapons_unlocked.duplicate()
		to_loader.items_unlocked = from_loader.items_unlocked.duplicate()
		to_loader.challenges_completed = from_loader.challenges_completed.duplicate()
		to_loader.difficulties_unlocked_serialized.clear()
		for difficulty_unlocked in from_loader.difficulties_unlocked_serialized:
			to_loader.difficulties_unlocked_serialized.push_back(difficulty_unlocked)
		to_loader.inactive_mods = from_loader.inactive_mods.duplicate()
		to_loader.read_announcements = from_loader.read_announcements.duplicate()
		to_loader.run_state_deserialized = from_loader.run_state_deserialized.duplicate()
		to_loader.data = from_loader.data.duplicate()
		to_loader.killed_enemies = from_loader.killed_enemies.duplicate()
		to_loader.killed_by_enemies = from_loader.killed_by_enemies.duplicate()
		to_loader.items_bought = from_loader.items_bought.duplicate()
		to_loader.save()

		if current_profile_id == to_id:
			load_with_generic_loader(to_loader)

## 通用设置默认值(音量/显示/语言/音轨等)
func init_general_options() -> Dictionary:
	return {
		"volume": {
			"master": 0.5, 
			"sound": 0.75, 
			"music": 0.25
		}, 
		"fullscreen": true, 
		"screenshake": true, 
		"language": "en", 
		"main_screen_keyart": 0, 
		"background": 0, 
		"visual_effects": true, 
		"damage_display": true, 
		"optimize_end_waves": false, 
		"limit_fps": false, 
		"mute_on_focus_lost": false, 
		"pause_on_focus_lost": true, 
		"on_lost_focus": 1, 
		"streamer_mode_tracks": true, 
		"legacy_tracks": false, 
		"deactivated_dlc_tracks": [], 
		"sort_inventory_presset": [], 
		"sort_inventory_presset_reverse": []
	}


## 玩法设置默认值(瞄准方式/血条/合作/DLC 停用列表等)
func init_gameplay_options() -> Dictionary:
	return {
		"mouse_only": false, 
		"manual_aim": false, 
		"manual_aim_on_mouse_press": false, 
		"movement_with_gamepad": true, 
		"hp_bar_on_character": true, 
		"hp_bar_on_bosses": true, 
		"keep_lock": true, 
		"lock_coop_camera": false, 
		"random_zone": false, 
		"endless_score_storing": 0, 
		"share_coop_loot": true, 
		"deactivated_dlcs": [], 
		"deactivated_skin_sets": [], 
		"no_item_appearance": false, 
		"holding_button": true, 
	}


## 无障碍设置默认值(敌人强度缩放/弹幕不透明度/品质颜色等);
## 主机版(非 GDK 桌面)唯一差异是默认字号 1.2 倍
func init_accessibilities_options() -> Dictionary:
	if not Utils.is_on_console() or Utils.on_gdk_desktop:
		return {
			"enemy_scaling": {
				"health": 1.0, 
				"damage": 1.0, 
				"speed": 1.0
			}, 
			"constant_projectile_option": 1, 
			"explosion_opacity": 1.0, 
			"projectile_opacity": 1.0, 
			"pet_opacity": 1.0, 
			"font_size": 1.0, 
			"character_highlighting": false, 
			"weapon_highlighting": false, 
			"projectile_highlighting": false, 
			"turret_highlighting": false, 
			"pet_highlighting": false, 
			"effects_icons_in_description": true, 
			"alt_gold_sounds": false, 
			"darken_screen": true, 
			"retry_wave": false, 
			"color_positive": Color.GREEN.to_html(), 
			"color_negative": Color.RED.to_html(), 
			"tier_0_color": DEFAULT_TIER_COLOR_0.to_html(), 
			"tier_1_color": DEFAULT_TIER_COLOR_1.to_html(), 
			"tier_2_color": DEFAULT_TIER_COLOR_2.to_html(), 
			"tier_3_color": DEFAULT_TIER_COLOR_3.to_html(), 
			"tier_4_color": DEFAULT_TIER_COLOR_4.to_html(), 
			"tier_5_color": DEFAULT_TIER_COLOR_5.to_html(), 
			"tier_0_color_dark": Color(0.0 / 255, 0.0 / 255, 0.0 / 255, 1).to_html(), 
			"tier_1_color_dark": Color(15.0 / 255, 32.0 / 255, 40.0 / 255, 1).to_html(), 
			"tier_2_color_dark": Color(16.0 / 255, 10.0 / 255, 27.0 / 255, 1).to_html(), 
			"tier_3_color_dark": Color(36.0 / 255, 9.0 / 255, 9.0 / 255, 1).to_html(), 
			"tier_4_color_dark": Color(36.0 / 255, 17.0 / 255, 8.0 / 255, 1).to_html(), 
			"tier_5_color_dark": Color(26.0 / 255, 24.0 / 255, 8.0 / 255, 1).to_html(), 
		}
	else:
		return {
			"enemy_scaling": {
				"health": 1.0, 
				"damage": 1.0, 
				"speed": 1.0
			}, 
			"constant_projectile_option": 1, 
			"explosion_opacity": 1.0, 
			"projectile_opacity": 1.0, 
			"pet_opacity": 1.0, 
			"font_size": 1.2, 
			"character_highlighting": false, 
			"weapon_highlighting": false, 
			"projectile_highlighting": false, 
			"turret_highlighting": false, 
			"pet_highlighting": false, 
			"effects_icons_in_description": true, 
			"alt_gold_sounds": false, 
			"darken_screen": true, 
			"retry_wave": false, 
			"color_positive": Color.GREEN.to_html(), 
			"color_negative": Color.RED.to_html(), 
			"tier_0_color": DEFAULT_TIER_COLOR_0.to_html(), 
			"tier_1_color": DEFAULT_TIER_COLOR_1.to_html(), 
			"tier_2_color": DEFAULT_TIER_COLOR_2.to_html(), 
			"tier_3_color": DEFAULT_TIER_COLOR_3.to_html(), 
			"tier_4_color": DEFAULT_TIER_COLOR_4.to_html(), 
			"tier_5_color": DEFAULT_TIER_COLOR_5.to_html(), 
			"tier_0_color_dark": Color(0.0 / 255, 0.0 / 255, 0.0 / 255, 1).to_html(), 
			"tier_1_color_dark": Color(15.0 / 255, 32.0 / 255, 40.0 / 255, 1).to_html(), 
			"tier_2_color_dark": Color(16.0 / 255, 10.0 / 255, 27.0 / 255, 1).to_html(), 
			"tier_3_color_dark": Color(36.0 / 255, 9.0 / 255, 9.0 / 255, 1).to_html(), 
			"tier_4_color_dark": Color(36.0 / 255, 17.0 / 255, 8.0 / 255, 1).to_html(), 
			"tier_5_color_dark": Color(26.0 / 255, 24.0 / 255, 8.0 / 255, 1).to_html(), 
		}


## 从游戏目录加载 DLC 资源包(.pck),使 res://dlcs/ 下的内容可见
func load_dlc_pcks() -> void :
	var dlc_pck_names: = ["BrotatoAbyssalTerrors.pck"]
	for dlc_name in dlc_pck_names:
		var dlc_path: String = Utils.get_game_dir() + "/" + dlc_name
		if FileAccess.file_exists(dlc_path):
			var success = ProjectSettings.load_resource_pack(dlc_path)
			if success:
				DebugService.log_data("Loaded DLC package: " + dlc_name)
			else:
				DebugService.log_data("Could not load DLC package: " + dlc_name)


## 扫描 res://dlcs/*/dlc_data.tres,校验所有权后加入 available_dlcs;
## 主机平台走系统侧 DLC 安装状态检查的快捷分支
func check_for_available_dlcs() -> void :
	var dir_path = "res://dlcs/"

	DebugService.log_data(dir_path + " exists: " + str(DirAccess.dir_exists_absolute(dir_path)))

	if not Utils.is_on_console() or Utils.on_editor:
		if not DirAccess.dir_exists_absolute(dir_path):
			return
	else:
		if not (SteamPlatform as Variant).steam.isDLCInstalled(DLC_1_APP_ID):
			return

		var dlc_data: = load(dir_path + "dlc_1/dlc_data.tres") as DLCData

		if dlc_data != null:
			DebugService.log_data("Found dlc file, loading resources from: " + str(dlc_data.my_id))
			available_dlcs.push_back(dlc_data)
			return ;

	DebugService.log_data("Open " + dir_path)

	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()

	var dlc_dirs: Array = []

	var dir_name = dir.get_next()
	while dir_name != "":
		if dir.current_is_dir():
			dlc_dirs.push_back(dir_path + dir_name)
		dir_name = dir.get_next()

	for path in dlc_dirs:
		dir = DirAccess.open(path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "dlc_data.tres":
				var dlc_data: = load(path + "/" + file_name) as DLCData
				# 4.x 移植: DLC 数据若因资源不兼容加载失败，跳过而不是崩溃
				if dlc_data == null:
					DebugService.log_data("DLC data failed to load (4.x migration): " + path)
					file_name = dir.get_next()
					continue
				if Platform.is_dlc_owned(dlc_data.my_id):
					DebugService.log_data("Found dlc file for: " + str(dlc_data.my_id))
					available_dlcs.push_back(dlc_data)
				else:
					DebugService.log_data("Dlc is not owned: " + str(dlc_data.my_id))

			file_name = dir.get_next()

	dir.list_dir_end()


## 中途退出时保存整局快照(供主菜单"继续游戏")并立即落盘
func save_run_state(
	shop_items: = [], 
	reroll_count: = [], 
	paid_reroll_count: = [], 
	initial_free_rerolls: = [], 
	free_rerolls: = [], 
	item_steals: = []
) -> void :
	saved_run_state = get_run_state(
		shop_items, 
		reroll_count, 
		paid_reroll_count, 
		initial_free_rerolls, 
		free_rerolls, 
		item_steals
	)
	last_saved_run_state = saved_run_state
	save()


## 清空局快照并落盘(一局正常结束后调用)
func reset_and_save_new_run_state() -> void :
	reset_and_save_run_state(_get_empty_run_state())


## 用给定快照覆盖并落盘;Switch 平台写入其专用版本号
func reset_and_save_run_state(run_state: Dictionary) -> void :
	saved_run_state = run_state
	if Utils.on_nintendo_nx_or_ounce:
		settings.version = VERSION_SWITCH
	else:
		settings.version = VERSION
	save()

## "继续游戏"可用性检查:快照使用了 DLC 地图或 DLC 角色
## 而 DLC 当前不可用时返回 false,禁用继续按钮
func check_dlc_valid_for_saved_run_state() -> bool:
	if ProgressData.saved_run_state.has_run_state == false:
		return true

	if saved_run_state.has("current_zone"):
		var current_zone = saved_run_state.current_zone
		if current_zone > 0:
			if not ProgressData.is_dlc_available("abyssal_terrors") and current_zone == 1:
				print("Not valid because save has DLC and DLC is not available")
				return false

	
	if not ProgressData.is_dlc_available("abyssal_terrors"):
		if saved_run_state.has("players_data"):
			for player in saved_run_state.players_data:
				var foundChar = false
				for character in ItemService.characters:
					if player.current_character != null and player.current_character.my_id == character.my_id:
						foundChar = true
				if foundChar == false:
					print("couldn't find player in list, probably in dlc, disable save")
					return false

	return true

## 在 RunData.get_state() 基础上附加商店相关状态(货架/重摇次数等),组成完整局快照
func get_run_state(
	shop_items: = [], 
	reroll_count: = [], 
	paid_reroll_count: = [], 
	initial_free_rerolls: = [], 
	free_rerolls: = [], 
	item_steals: = []
) -> Dictionary:
	var run_state = RunData.get_state()
	run_state["has_run_state"] = true
	run_state["shop_items"] = shop_items.duplicate(true)
	run_state["reroll_count"] = reroll_count.duplicate()
	run_state["paid_reroll_count"] = paid_reroll_count.duplicate()
	run_state["initial_free_rerolls"] = initial_free_rerolls.duplicate()
	run_state["free_rerolls"] = free_rerolls.duplicate()
	run_state["item_steals"] = item_steals.duplicate()

	return run_state


## 确定 SAVE_DIR/SAVE_PATH/LOG_PATH(user:// + 平台用户 ID,支持多账号);
## 目录首次创建时(非主机)从旧版 fallback 目录迁移存档文件
func init_save_paths(user_dir_override: = "user://") -> void :
	var dir_path = user_dir_override + Platform.get_user_id()
	var directory_exists = DirAccess.dir_exists_absolute(dir_path)
	if not directory_exists:
		var err = DirAccess.make_dir_absolute(dir_path)
		if err != OK:
			printerr("Could not create the directory %s. Error code: %s" % [dir_path, err])
			return

	SAVE_DIR = dir_path
	if BETA:
		SAVE_PATH = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id).save_path
	else:
		SAVE_PATH = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id).save_path
	LOG_PATH = dir_path + "/log.txt"
	print("LOG_PATH: " + str(LOG_PATH))
	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file != null:
		file.close()

	if not Utils.is_on_console() and not directory_exists:
		_copy_files_from_fallback_dir(user_dir_override)

## 切换当前档位 ID 并立即写入 settings.json(记住上次使用的档位)
func set_current_profile_id(profile_id: int) -> void :
	current_profile_id = profile_id
	save_settings()
	print("ProgressData: Set current profile id to %s." % [current_profile_id])

## 读取 settings.json 合并进默认设置;文件缺失/损坏时回退默认值与 0 号档位
func load_settings():
	var file_path = SAVE_DIR + SETTINGS_FILE_NAME
	var file = FileAccess.open(file_path, FileAccess.READ)
	var error_read = OK if file != null else FileAccess.get_open_error()
	if error_read != OK:
		printerr("ProgressData: Could not read %s." % [file_path])
		set_current_profile_id(0)
		return

	var test_json_conv = JSON.new()
	var parse_error = test_json_conv.parse(file.get_as_text())
	if parse_error != OK:

		printerr("ProgressData: Settings are corrupted. Use default settings instead.")
		set_current_profile_id(0)
		return

	var parse_result = test_json_conv.get_data()
	if parse_result.has("current_profile_id"):
		current_profile_id = parse_result.get("current_profile_id", 0)
	else:
		current_profile_id = 0
	settings = Utils.merge_dictionaries(settings, parse_result.settings)
	file.close()

	set_current_profile_id(current_profile_id)
	if current_profile_id < 0 or current_profile_id >= profile_count:
		printerr("ProgressData: Invalid profile id %s. Resetting to 0." % [current_profile_id])
		set_current_profile_id(0)

## 将设置与当前档位 ID 写入 settings.json(编辑器下带缩进便于阅读)
func save_settings() -> void :
	var file_path = SAVE_DIR + SETTINGS_FILE_NAME
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	var error_write = OK if file != null else FileAccess.get_open_error()
	if error_write != OK:
		printerr("ProgressData: Could not write %s." % [file_path])
		return

	var json_data = {"current_profile_id": current_profile_id, "settings": settings}

	var sort_keys: = true
	var indent = ""
	if OS.has_feature("editor"):
		indent = "  "
	var json_string: = JSON.stringify(json_data, indent, sort_keys)
	file.store_string(json_string)
	file.close()
	print("ProgressData: Saved current profile id %s to %s." % [current_profile_id, file_path])

## 切换到指定档位:清空内存 → 重新加载存档 → 补默认解锁 → 重置 RunData
func load_profile_save(profile_id: int) -> void :
	if profile_id < 0 or profile_id >= profile_count:
		printerr("ProgressData: Invalid profile id %s. Resetting to 0." % [profile_id])
		profile_id = 0
	set_current_profile_id(profile_id)
	reset()
	difficulties_unlocked.clear()
	load_game_file()
	add_unlocked_by_default()
	set_max_selectable_difficulty()
	RunData.reset()
	print("ProgressData: Loaded profile id %s." % [current_profile_id])

## 从旧版存档目录(user)把所有文件拷贝到当前 SAVE_DIR
func _copy_files_from_fallback_dir(user_dir_override: String) -> void :
	var dir_path: String = user_dir_override + fallback_dir_name
	if DirAccess.dir_exists_absolute(dir_path) and dir_path != SAVE_DIR:
		print("fallback save dir found at %s. Copying files into %s" % [dir_path, SAVE_DIR])
		var dir: DirAccess = DirAccess.open(dir_path)
		var err: int = OK if dir != null else DirAccess.get_open_error()
		if err != OK:
			printerr("Could not change directory to %s. Error code: %s" % [dir_path, err])
			return

		err = dir.list_dir_begin()
		if err != OK:
			printerr("Could not list directory %s. Error code: %s" % [dir_path, err])
			return

		var filename: String = dir.get_next()
		while filename != "":
			if not dir.current_is_dir():
				var file_path: String = dir.get_current_dir() + "/" + filename
				err = dir.copy(file_path, SAVE_DIR + "/" + filename)
				if err != OK:
					printerr("Could not copy file %s. Error code: %s" % [file_path, err])
			filename = dir.get_next()


## 存档加载主流程:按 v3 → v2(成功后再合并 v1)→ v1 的顺序降级尝试。
## - 文件损坏(状态非 SAVE_MISSING)时立即中止,不再向下尝试,避免旧版覆盖新档
## - v1 加载成功即 save() 落成 v3 格式,完成迁移
## - 全部缺失时先试 fallback 目录,再不行才建新档
func load_game_file(try_fallback: = true) -> void :
	if DebugService.reinitialize_save:
		save()
		return

	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id)
		load_with_generic_loader(loader_beta)
		show_main_title_beta_save_warning_popup = loader_beta.show_main_title_beta_save_warning_popup
		if load_status == LoadStatus.SAVE_OK:
			return
		if load_status != LoadStatus.SAVE_MISSING:
			
			return


	print("--- Load game file ---")
	print("Try to load save v3")
	var loader_v3 = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id)
	load_with_generic_loader(loader_v3)
	if load_status == LoadStatus.SAVE_OK:
		return
	if load_status != LoadStatus.SAVE_MISSING:
		
		return

	
	# 1/2 号档位没有旧版存档可迁移(v1/v2 只有单档位),缺失时直接建新档
	if current_profile_id > 0:
		load_status = LoadStatus.SAVE_OK
		save()
		return

	print("No save v3. Try to load save v2")
	var loader_v2 = ProgressDataLoaderV2.new(SAVE_DIR)
	load_with_generic_loader(loader_v2)
	if load_status == LoadStatus.SAVE_OK:
		print("Save v2 OK, try to merge old V1")
		merge_old_v1_save()
		return
	if load_status != LoadStatus.SAVE_MISSING:
		
		print("Save v2 corrupted. Not trying v1")
		return

	var loader_v1 = null

	print("No save v2. Try to load save v1")
	if Utils.is_on_console():
		loader_v1 = ProgressDataLoaderV1.new("user:/")
	else:
		loader_v1 = ProgressDataLoaderV1.new(SAVE_DIR)

	load_with_generic_loader(loader_v1)
	if load_status == LoadStatus.SAVE_OK:
		print("Migrating v1 save to v3")
		save()
		return
	elif load_status != LoadStatus.SAVE_MISSING:
		
		print("Save v1 corrupted")
	else:
		if try_fallback and not Utils.is_on_console():
			print("No save found, trying to copy from fallback")
			_use_fallback_save()
			return
		print("No save found, creating new save")
		load_status = LoadStatus.SAVE_OK
		save()


## 从 fallback 目录拷贝存档后重试加载(try_fallback = false 防止递归)
func _use_fallback_save() -> void :
	var split: = SAVE_DIR.split("//")
	_copy_files_from_fallback_dir(split[0] + "//")
	load_game_file(false)


## 所有版本 loader 共用的"入库"流程:让 loader 读盘,再把结果去重合并进内存
## (解锁数组、难度信息、局快照、统计)。
func load_with_generic_loader(loader, path: = "") -> void :
	loader.load_game_file(path)
	load_status = loader.load_status

	if load_status == LoadStatus.CORRUPTED_ALL_SAVES:
		return
	if load_status == LoadStatus.SAVE_MISSING:
		return

	_append_without_duplicates(zones_unlocked, loader.zones_unlocked)
	_append_without_duplicates(characters_unlocked, loader.characters_unlocked)
	_append_without_duplicates(upgrades_unlocked, loader.upgrades_unlocked)
	_append_without_duplicates(consumables_unlocked, loader.consumables_unlocked)
	_append_without_duplicates(weapons_unlocked, loader.weapons_unlocked)
	_append_without_duplicates(items_unlocked, loader.items_unlocked)

	var challenges_completed_hash: Array = Utils.convert_to_hash_array(loader.challenges_completed)

	_append_without_duplicates(challenges_completed, challenges_completed_hash)

	for difficulty_json in loader.difficulties_unlocked_serialized:
		var difficulty: = CharacterDifficultyInfo.new()
		difficulty.deserialize_and_merge(difficulty_json)
		difficulties_unlocked.append(difficulty)

	_dedublicate_difficulties_unlocked()

	inactive_mods = loader.inactive_mods.duplicate()
	read_announcements = loader.read_announcements.duplicate()

	saved_run_state = Utils.merge_dictionaries(saved_run_state, loader.run_state_deserialized)
	
	# JSON 反序列化出的数字均为 float:整数语义字段必须转回 int,
	# 否则后续比较与再序列化会出问题
	for k in ["nb_of_waves", "current_wave", "current_difficulty", "bonus_gold", "retries"]:
		if saved_run_state.has(k) and typeof(saved_run_state[k]) == TYPE_FLOAT:
			saved_run_state[k] = int(saved_run_state[k])
	for k in ["reroll_count", "paid_reroll_count", "initial_free_rerolls", "free_rerolls"]:
		if saved_run_state.has(k) and typeof(saved_run_state[k]) == TYPE_ARRAY:
			for i in saved_run_state[k].size():
				if typeof(saved_run_state[k][i]) == TYPE_FLOAT:
					saved_run_state[k][i] = int(saved_run_state[k][i])

	# v1/v2 存档把设置与进度混存在一个文件里,需一并合并设置
	if loader is ProgressDataLoaderV1 or loader is ProgressDataLoaderV2:
		settings = Utils.merge_dictionaries(settings, loader.settings)

	data = Utils.merge_dictionaries(data, loader.data)
	# 统计计数同样做 float→int 归一化
	for k in ["enemies_killed", "materials_collected", "trees_killed", "steps_taken", "enemies_killed_far_away"]:
		if data.has(k):
			
			data[k] = int(data[k])

	# 图鉴统计(击杀/被杀/购买)是 v3 之后才有的字段
	if not (loader is ProgressDataLoaderV1) and not (loader is ProgressDataLoaderV2):
		killed_enemies = Utils.merge_dictionaries(killed_enemies, loader.killed_enemies)
		for k in killed_enemies.keys():
			killed_enemies[k] = int(killed_enemies[k])

		killed_by_enemies = Utils.merge_dictionaries(killed_by_enemies, loader.killed_by_enemies)
		for k in killed_by_enemies.keys():
			killed_by_enemies[k] = int(killed_by_enemies[k])

		items_bought = Utils.merge_dictionaries(items_bought, loader.items_bought)
		for k in items_bought.keys():
			items_bought[k] = int(items_bought[k])


## 按 character_id / zone_id 去重难度记录(多份存档合并时可能产生重复)
func _dedublicate_difficulties_unlocked() -> void :
	var processed_characters: = {}
	var new_difficulties_unlocked: = []
	for difficulty in difficulties_unlocked:
		if not difficulty.character_id in processed_characters:
			new_difficulties_unlocked.append(difficulty)
			processed_characters[difficulty.character_id] = true

		var processed_zones: = {}
		var new_zones_difficulty_info: = []
		for zone_diff_info in difficulty.zones_difficulty_info:
			if not zone_diff_info.zone_id in processed_zones:
				new_zones_difficulty_info.append(zone_diff_info)
				processed_zones[zone_diff_info.zone_id] = true

		difficulty.zones_difficulty_info = new_zones_difficulty_info
	difficulties_unlocked = new_difficulties_unlocked


## 落盘:先写设置,再把内存状态灌入 v3(或 Beta)loader 序列化保存。
## 所有存档均损坏且无云备份可恢复时拒绝保存,避免覆盖可能救回的数据
func save() -> void :
	if DebugService.disable_saving:
		return
	if load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_STEAM or load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_EPIC:
		printerr("Aborting save due to unrecoverable corruption")
		return
	save_settings()

	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id)
		_set_loader_properties_beta(loader_beta, saved_run_state)
		loader_beta.show_main_title_beta_save_warning_popup = show_main_title_beta_save_warning_popup
		loader_beta.save()
	else:
		var loader_v3 = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id)
		_set_loader_properties(loader_v3, saved_run_state)
		loader_v3.save()



## 返回当前状态序列化后的存档字典(不写盘,云存档/对比用)
func get_current_save_object() -> Dictionary:
	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id)
		_set_loader_properties_beta(loader_beta, _get_current_run_state())
		return loader_beta.get_save_object()

	var loader_v3 = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id)
	_set_loader_properties(loader_v3, _get_current_run_state())
	return loader_v3.get_save_object()


## 每次加载存档后调用:把各 Service 中标记 unlocked_by_default 的资源
## 补进解锁数组(以 ID 哈希存储,故先 _generate_hashes),
## 并保证每个角色对每张默认解锁地图都有一条难度进度记录
func add_unlocked_by_default() -> void :
	for zone in ZoneService.zones:
		if zone.unlocked_by_default and not zones_unlocked.has(zone.my_id):
			zones_unlocked.push_back(zone.my_id)

	for item in ItemService.items:
		
		
		item._generate_hashes()
		if item.unlocked_by_default and not items_unlocked.has(item.my_id_hash):
			items_unlocked.push_back(item.my_id_hash)

	for weapon in ItemService.weapons:
		
		
		weapon._generate_hashes()
		if weapon.unlocked_by_default and not weapons_unlocked.has(weapon.weapon_id_hash):
			weapons_unlocked.push_back(weapon.weapon_id_hash)

	for upgrade in ItemService.upgrades:
		
		
		upgrade._generate_hashes()
		if upgrade.unlocked_by_default and not upgrades_unlocked.has(upgrade.upgrade_id_hash):
			upgrades_unlocked.push_back(upgrade.upgrade_id_hash)

	for character in ItemService.characters:
		
		
		character._generate_hashes()
		if character.unlocked_by_default and not characters_unlocked.has(character.my_id_hash):
			characters_unlocked.push_back(character.my_id_hash)

	for consumable in ItemService.consumables:
		
		
		consumable._generate_hashes()
		if consumable.unlocked_by_default and not consumables_unlocked.has(consumable.my_id_hash):
			consumables_unlocked.push_back(consumable.my_id_hash)

	for character in ItemService.characters:
		var character_difficulty_info_exists = false
		var existing_zones_difficulty_info = []
		var char_diff_info_to_modify: = CharacterDifficultyInfo.new(character.my_id)

		for difficulty_unlocked in difficulties_unlocked:
			if difficulty_unlocked.character_id == character.my_id:
				character_difficulty_info_exists = true
				char_diff_info_to_modify = difficulty_unlocked
				for zone_diff_info in difficulty_unlocked.zones_difficulty_info:
					existing_zones_difficulty_info.push_back(zone_diff_info.zone_id)

		for zone in ZoneService.zones:
			if zone.unlocked_by_default:
				var already_has_zone_diff_info = existing_zones_difficulty_info.has(zone.my_id)

				if not already_has_zone_diff_info:
					char_diff_info_to_modify.zones_difficulty_info.push_back(ZoneDifficultyInfo.new(zone.my_id))

		if not character_difficulty_info_exists:
			difficulties_unlocked.push_back(char_diff_info_to_modify)


# ---------- 全解锁 / 全上锁(调试与"全解锁存档"功能用) ----------

## 全解锁:图鉴、角色、武器、难度、挑战全开
func unlock_all() -> void :
	for zone in ZoneService.zones:
		if zone.unlocked_by_default:
			zones_unlocked.push_back(zone.my_id)

	unlock_all_items()
	unlock_all_weapoons()
	unlock_all_characters()
	unlock_all_enemies()
	unlock_all_difficulties()

	ChallengeService.complete_all_challenges()


func unlock_all_items() -> void :
	for item in ItemService.items:
		items_unlocked.push_back(item.get_my_id_hash())
		items_bought[item.my_id_hash] = 10

	for upgrade in ItemService.upgrades:
		if not upgrades_unlocked.has(upgrade.upgrade_id_hash):
			upgrades_unlocked.push_back(upgrade.upgrade_id_hash)

	for consumable in ItemService.consumables:
		if consumable.unlocked_by_default and not consumables_unlocked.has(consumable.get_my_id_hash()):
			consumables_unlocked.push_back(consumable.get_my_id_hash())

func unlock_all_weapoons() -> void :
	for weapon in ItemService.weapons:
		if not weapons_unlocked.has(weapon.get_weapon_id_hash()):
			weapons_unlocked.push_back(weapon.my_id_hash)
		items_bought[weapon.my_id_hash] = 10

func unlock_all_characters() -> void :
	for character in ItemService.characters:
		characters_unlocked.push_back(character.get_my_id_hash())

func unlock_all_enemies() -> void :
	for enemy in ItemService.entities:
		killed_enemies[enemy.my_id_hash] = 1000



## 重建难度表:所有角色 × 默认地图的可选危险度直接拉满
func unlock_all_difficulties() -> void :
	difficulties_unlocked = []
	for character in ItemService.characters:
		var character_diff_info = CharacterDifficultyInfo.new(character.my_id)

		for zone in ZoneService.zones:
			if zone.unlocked_by_default:
				var info = ZoneDifficultyInfo.new(zone.my_id)
				info.max_selectable_difficulty = MAX_DIFFICULTY
				character_diff_info.zones_difficulty_info.push_back(info)

		difficulties_unlocked.push_back(character_diff_info)

func lock_all() -> void :
	lock_all_items()
	lock_all_weapons()
	lock_all_characters()
	lock_all_enemies()
	lock_all_difficulties()
	ProgressData.challenges_completed.clear()

func lock_all_items() -> void :
	items_bought.clear()
	upgrades_unlocked.clear()
	consumables_unlocked.clear()

func lock_all_weapons() -> void :
	items_bought.clear()

func lock_all_characters() -> void :
	# 注:先 push 再整体 clear,循环实际无效果(原作即如此)
	for character in ItemService.characters:
		if character.unlocked_by_default:
			characters_unlocked.push_back(character.my_id)
	characters_unlocked.clear()

func lock_all_enemies() -> void :
	killed_enemies.clear()

func lock_all_difficulties() -> void :
	difficulties_unlocked.clear()

## 把全体角色/地图中已解锁的最高可选危险度推平到所有角色与地图
## (任一角色打上去的危险度全员可选),并把超出 MAX_DIFFICULTY 的历史数据钳制回来
func set_max_selectable_difficulty() -> void :
	var overall_max_selectable_difficulty: = 0
	for difficulty_info in difficulties_unlocked:
		for zone_difficulty_info in difficulty_info.zones_difficulty_info:
			overall_max_selectable_difficulty = int(max(overall_max_selectable_difficulty, zone_difficulty_info.max_selectable_difficulty))

	for difficulty in difficulties_unlocked:
		for zone_difficulty_info in difficulty.zones_difficulty_info:
			if zone_difficulty_info.max_selectable_difficulty < overall_max_selectable_difficulty:
				zone_difficulty_info.max_selectable_difficulty = overall_max_selectable_difficulty

			if zone_difficulty_info.max_difficulty_beaten.difficulty_value > MAX_DIFFICULTY:
				zone_difficulty_info.max_difficulty_beaten.difficulty_value = MAX_DIFFICULTY

			if zone_difficulty_info.max_endless_wave_beaten.difficulty_value > MAX_DIFFICULTY:
				zone_difficulty_info.max_endless_wave_beaten.difficulty_value = MAX_DIFFICULTY

## 使设置实际生效:语言 locale、全屏、音量、FPS 上限(启动与设置变更后调用)
func apply_settings() -> void :
	_apply_sounds_settings()

	TranslationServer.set_locale(settings.language)

	if not DebugService.no_fullscreen_on_launch:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN if (settings.fullscreen) else Window.MODE_WINDOWED

	if Utils.is_on_console() and not Utils.on_gdk_desktop:
		
		settings.font_size = 1.2


	# 4.x 移植: 字号已不存于字体资源(FontVariation 无 size/fixed_size),
	# 3.x 通过改共享 DynamicFont.size 实现的无障碍字号缩放需另行重设计,
	# 这里仅保留设置值,避免对不存在的属性赋值导致报错
	RunData.reset_background()
	set_fps_limit(settings.limit_fps)


## 线性音量值转 dB 写入 Master/Sound/Music 三条音频总线
func _apply_sounds_settings() -> void :
	if settings.has("volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(settings.volume.master ))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sound"), linear_to_db(settings.volume.sound))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(settings.volume.music))


func set_font_size(value: float) -> void :
	if Utils.is_on_console() and not Utils.on_gdk_desktop:
		
		value = 1.2

	# 4.x 移植: 同 _apply_display_settings,字号缩放待重设计,仅记录设置
	settings.font_size = value


## 开关帧率上限(FPS_LIMIT / 不限制)并记录设置
func set_fps_limit(enabled: bool) -> void :
	Engine.max_fps = FPS_LIMIT if enabled else 0
	settings.limit_fps = enabled


# ---------- DLC 开关。"可用" = 已安装且拥有;"激活" = 可用且未被玩家停用 ----------

## 所有可用 DLC 的 ID
func get_all_available_dlc_ids() -> Array:
	var ids = []

	for dlc in available_dlcs:
		ids.push_back(dlc.my_id)

	return ids


## 继续旧局时按快照保存时的 enabled_dlcs 临时增删 DLC 资源,
## 保证局内内容与保存时一致(与玩家当前设置无关)
func update_dlc_resources_based_on_run_state(state: Dictionary) -> void :
	for enabled_dlc_id in state.enabled_dlcs:
		if enabled_dlc_id in settings.deactivated_dlcs:
			var dlc_data = get_dlc_data(enabled_dlc_id)

			if dlc_data:
				dlc_data.add_resources()

	for active_dlc_id in get_active_dlc_ids():
		if not active_dlc_id in state.enabled_dlcs:
			var dlc_data = get_dlc_data(active_dlc_id)

			if dlc_data:
				dlc_data.remove_resources()


## 激活的 DLC(可用且未停用);GUT 测试场景下视为全无
func get_active_dlc_ids() -> Array:
	if get_tree().current_scene.name == "GutRunner":
		return []

	var active_dlcs = get_all_available_dlc_ids()

	for deactivated_dlc_id in settings.deactivated_dlcs:
		active_dlcs.erase(deactivated_dlc_id)

	return active_dlcs


## 激活的 DLC 音轨(音轨开关独立于 DLC 内容开关)
func get_active_dlc_tracks() -> Array:
	var ids = get_all_available_dlc_ids()

	for deactivated_dlc_id in settings.deactivated_dlc_tracks:
		ids.erase(deactivated_dlc_id)

	return ids


## 按当前设置重置资源:全部移除后仅注册激活的 DLC(退出旧局回菜单时)
func reset_dlc_resources_to_active_dlcs() -> void :
	if get_tree().current_scene.name == "GutRunner":
		return

	for dlc in available_dlcs:
		dlc.remove_resources()

	for dlc_id in get_active_dlc_ids():
		var dlc_data = get_dlc_data(dlc_id)
		if dlc_data:
			dlc_data.add_resources()


## 按 ID 查找可用 DLC 数据,未找到返回 null
func get_dlc_data(dlc_id: String) -> DLCData:
	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			return dlc

	return null


## 跳过设置检查直接注册 DLC 资源(配合 update_dlc_resources_based_on_run_state)
func force_activate_dlc(dlc_id: String) -> void :
	print("force activate dlc " + dlc_id)

	
	
	
	

	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			dlc.add_resources()

	add_unlocked_by_default()
	RunData.reset()
	emit_signal("dlc_activated", dlc_id)


## 跳过设置检查直接移除 DLC 资源
func force_deactivate_dlc(dlc_id: String) -> void :

	print("force deactivate dlc " + dlc_id)

	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			print("remove resources for dlc " + dlc.my_id)
			dlc.remove_resources()

	RunData.current_zone = 0
	RunData.reset()
	emit_signal("dlc_deactivated", dlc_id)


## 玩家在设置中启用 DLC:移出停用列表、注册资源、补默认解锁、发信号
func activate_dlc(dlc_id: String) -> void :

	print("activate dlc " + dlc_id)

	if get_active_dlc_ids().has(dlc_id) and not get_tree().current_scene.name == "GutRunner":
		print(dlc_id + " already exists")
		return

	settings.deactivated_dlcs.erase(dlc_id)

	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			dlc.add_resources()

	add_unlocked_by_default()
	RunData.reset()
	emit_signal("dlc_activated", dlc_id)


## 玩家在设置中停用 DLC:记入停用列表、移除资源、切回默认地图、发信号
func deactivate_dlc(dlc_id: String) -> void :

	print("deactivate dlc " + dlc_id)

	if settings.deactivated_dlcs.has(dlc_id):
		print(dlc_id + " doesn't exist")
		return

	settings.deactivated_dlcs.push_back(dlc_id)
	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			dlc.remove_resources()

	RunData.current_zone = 0
	RunData.reset()
	emit_signal("dlc_deactivated", dlc_id)


## DLC 是否可用(不考虑玩家开关)
func is_dlc_available(dlc_id: String) -> bool:
	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			return true
	return false


## 六档品质颜色是否均接近默认值(容差 0.05,用于设置页判断是否被自定义过)
func is_colors_tier_by_default() -> bool:
	if not _color_distance(DEFAULT_TIER_COLOR_0, Color(settings.tier_0_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_1, Color(settings.tier_1_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_2, Color(settings.tier_2_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_3, Color(settings.tier_3_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_4, Color(settings.tier_4_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_5, Color(settings.tier_5_color)) < 0.05:
		return false
	return true


## RGB 空间的欧氏距离(忽略 alpha)
func _color_distance(color_1: Color, color_2: Color) -> float:
	var vector_1: = Vector3(color_1.r, color_1.g, color_1.b)
	var vector_2: = Vector3(color_2.r, color_2.g, color_2.b)
	return vector_1.distance_to(vector_2)


## DLC 可用且未被玩家停用
func is_dlc_available_and_active(dlc_id: String) -> bool:
	var is_available = is_dlc_available(dlc_id)

	if not is_available:
		return false

	return not settings.deactivated_dlcs.has(dlc_id)


## 查询角色在某地图的难度进度(注意:入参 character_id 实为 character_id_hash)。
## 随机地图模式返回完成度最低的那张图的记录;查不到则返回一条全新记录
func get_character_difficulty_info(character_id: int, zone_id: int, is_random_zone: bool = false) -> ZoneDifficultyInfo:

	for character_difficulty_info in difficulties_unlocked:
		assert (character_difficulty_info.character_id_hash != Keys.empty_hash)
		if character_difficulty_info.character_id_hash != character_id: continue

		if is_random_zone:
			var lowest_difficulty = 999
			var current_zone_difficulty_info
			for zone_difficulty_info in character_difficulty_info.zones_difficulty_info:
				if (zone_difficulty_info.max_difficulty_beaten.difficulty_value < lowest_difficulty):
					lowest_difficulty = zone_difficulty_info.max_difficulty_beaten.difficulty_value
					current_zone_difficulty_info = zone_difficulty_info
			if (lowest_difficulty == 999): continue
			return current_zone_difficulty_info
		else:
			for zone_difficulty_info in character_difficulty_info.zones_difficulty_info:
				if zone_difficulty_info.zone_id != zone_id: continue
				return zone_difficulty_info

	return ZoneDifficultyInfo.new(zone_id)


## data 统计计数 +1(键必须已存在,见 get_fresh_data)
func increment_stat(key: String) -> void :
	data[key] += 1


## 把内存状态灌入 Beta loader 供其序列化(Beta 存档不做 ID 哈希转换)
func _set_loader_properties_beta(loader_v3: ProgressDataLoaderBeta, run_state: Dictionary) -> void :
	loader_v3.zones_unlocked = zones_unlocked.duplicate()
	loader_v3.characters_unlocked = characters_unlocked.duplicate()
	loader_v3.upgrades_unlocked = upgrades_unlocked.duplicate()
	loader_v3.consumables_unlocked = consumables_unlocked.duplicate()
	loader_v3.weapons_unlocked = weapons_unlocked.duplicate()
	loader_v3.items_unlocked = items_unlocked.duplicate()
	loader_v3.challenges_completed = challenges_completed.duplicate()
	loader_v3.difficulties_unlocked_serialized.clear()
	for difficulty_unlocked in difficulties_unlocked:
		loader_v3.difficulties_unlocked_serialized.push_back(difficulty_unlocked.serialize())
	loader_v3.inactive_mods = inactive_mods.duplicate()
	loader_v3.read_announcements = read_announcements.duplicate()
	loader_v3.run_state_deserialized = run_state.duplicate()
	loader_v3.data = data.duplicate()
	loader_v3.killed_enemies = killed_enemies.duplicate()
	loader_v3.killed_by_enemies = killed_by_enemies.duplicate()
	loader_v3.items_bought = items_bought.duplicate()

## 把内存状态灌入 v3 loader 供其序列化;写盘前把各解锁数组统一转为 ID 哈希
func _set_loader_properties(loader_v3: ProgressDataLoaderV3, run_state: Dictionary) -> void :
	loader_v3.zones_unlocked = zones_unlocked.duplicate()

	
	loader_v3.characters_unlocked = Utils.convert_to_hash_array(characters_unlocked.duplicate())
	loader_v3.upgrades_unlocked = Utils.convert_to_hash_array(upgrades_unlocked.duplicate())
	loader_v3.consumables_unlocked = Utils.convert_to_hash_array(consumables_unlocked.duplicate())
	loader_v3.weapons_unlocked = Utils.convert_to_hash_array(weapons_unlocked.duplicate())
	loader_v3.items_unlocked = Utils.convert_to_hash_array(items_unlocked.duplicate())
	loader_v3.challenges_completed = Utils.convert_to_hash_array(challenges_completed.duplicate())
	loader_v3.difficulties_unlocked_serialized.clear()
	for difficulty_unlocked in difficulties_unlocked:
		loader_v3.difficulties_unlocked_serialized.push_back(difficulty_unlocked.serialize())
	loader_v3.inactive_mods = inactive_mods.duplicate()
	loader_v3.read_announcements = read_announcements.duplicate()
	loader_v3.run_state_deserialized = run_state.duplicate()
	loader_v3.data = data.duplicate()
	loader_v3.killed_enemies = killed_enemies.duplicate()
	loader_v3.killed_by_enemies = killed_by_enemies.duplicate()
	loader_v3.items_bought = items_bought.duplicate()


## 当前局快照:已有存档快照则沿用其商店状态,否则取 RunData 实时状态
func _get_current_run_state() -> Dictionary:
	if saved_run_state.has_run_state:
		
		return get_run_state(
			saved_run_state.shop_items, 
			saved_run_state.reroll_count, 
			saved_run_state.paid_reroll_count, 
			saved_run_state.initial_free_rerolls, 
			saved_run_state.free_rerolls, 
			saved_run_state.item_steals
		)
	else:
		return get_run_state()


## 空局快照("继续游戏"不可用的状态)
func _get_empty_run_state() -> Dictionary:
	return {"has_run_state": false}


## 把 array_to_append 中的新元素追加进 array(用字典作集合去重)
func _append_without_duplicates(array: Array, array_to_append: Array) -> void :
	var dict: = {}
	for item in array:
		dict[item] = true
	for item in array_to_append:
		if not dict.has(item):
			array.push_back(item)
			dict[item] = true

## 轻量读取 3 个档位的概要信息(存档选择界面显示用)
func get_profile_stats() -> Array:
	var result = []
	for i in range(3):
		if BETA:
			var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, i)
			var stats = loader_beta.load_profile_stats()
			result.push_back(stats)
		else:
			var loader = ProgressDataLoaderV3.new(SAVE_DIR, i)
			var stats = loader.load_profile_stats()
			result.push_back(stats)
	return result

## 切换语言:校验后写设置、设 locale、发 language_changed 信号
func change_language(new_language: String) -> void :
	if not new_language in languages:
		printerr("Language %s is not a valid language option" % new_language)
		return

	settings.language = new_language
	TranslationServer.set_locale(new_language)
	emit_signal("language_changed")


# ---------- 图鉴/成就完成率(进度统计界面用) ----------

## 挑战完成率(不计难度奖励类挑战)
func get_percent_challenges_unlocked() -> float:
	var all_challenge_counter: int = 0
	for challenge in ChallengeService.challenges:
		if challenge.reward_type == RewardType.DIFFICULTY:
			continue
		all_challenge_counter += 1
	var all_challenges_unlocked: int = get_profile_stats()[current_profile_id].challenges_completed
	return float(all_challenges_unlocked) / float(all_challenge_counter)


## 图鉴物品点亮率(以是否购买过计)
func get_percent_items_unlocked() -> float:
	var all_items: int = ItemService.items.size()
	var all_items_unlocked: int = 0
	for item in ItemService.items:
		if items_bought.has(item.my_id_hash):
			all_items_unlocked += 1
	return float(all_items_unlocked) / float(all_items)


## 图鉴武器点亮率(以是否购买过计)
func get_percent_weapons_unlocked() -> float:
	var all_weapons: int = ItemService.weapons.size()
	var all_weapons_unlocked: int = 0
	for weapon in ItemService.weapons:
		if items_bought.has(weapon.my_id_hash):
			all_weapons_unlocked += 1
	return float(all_weapons_unlocked) / float(all_weapons)


## 图鉴敌人点亮率(总数减 1 排除隐藏条目,以杀过为计)
func get_percent_enemies_unlocked() -> float:
	var all_entities: int = ItemService.entities.size() - 1
	var all_entities_unlocked: int = killed_enemies.size()
	return float(all_entities_unlocked) / float(all_entities)

## 未安装 DLC1 时打开商店页;编辑器模式下直接调试注入 DLC
func show_store_dlc1() -> void :
	if OS_Seaven.is_in_editor_mode():
		if not (SteamPlatform as Variant).steam.isDLCInstalled(DLC_1_APP_ID):
			(SteamPlatform as Variant).steam.debugAddDlc(DLC_1_APP_ID)

		return

	if not (SteamPlatform as Variant).steam.isDLCInstalled(DLC_1_APP_ID):
		OS_Seaven.show_product_store(str(DLC_1_APP_ID))


## 重新扫描可用 DLC(系统侧 DLC 安装/卸载变更后调用)
func read_all_dlcs() -> void :
	print("read all dlcs")
	available_dlcs.clear()
	check_for_available_dlcs()


## v2 存档加载成功后调用:把可能并存的 v1 存档按"取最大值"策略合并进来
## (v1 与 v2 曾并行存在,双方进度可能各有领先)
func merge_old_v1_save() -> void :

	var loader_v1 = null

	if Utils.is_on_console():
		loader_v1 = ProgressDataLoaderV1.new("user:/")
	else:
		loader_v1 = ProgressDataLoaderV1.new(SAVE_DIR)

	loader_v1.load_game_file("")
	load_status = loader_v1.load_status

	if load_status == LoadStatus.SAVE_MISSING:
		
		load_status = LoadStatus.SAVE_OK
		return
	if load_status == LoadStatus.CORRUPTED_ALL_SAVES:
		return

	print("Try to merge save version 1")

	_append_without_duplicates(zones_unlocked, loader_v1.zones_unlocked)
	_append_without_duplicates(characters_unlocked, loader_v1.characters_unlocked)
	_append_without_duplicates(upgrades_unlocked, loader_v1.upgrades_unlocked)
	_append_without_duplicates(consumables_unlocked, loader_v1.consumables_unlocked)
	_append_without_duplicates(weapons_unlocked, loader_v1.weapons_unlocked)
	_append_without_duplicates(items_unlocked, loader_v1.items_unlocked)

	var challenges_completed_hash: Array = Utils.convert_to_hash_array(loader_v1.challenges_completed)
	_append_without_duplicates(challenges_completed, challenges_completed_hash)

	var overall_max_selectable_difficulty: = 0
	for difficulty_json in loader_v1.difficulties_unlocked_serialized:
		for difficulty in difficulties_unlocked:
			if difficulty.character_id == difficulty_json.character_id:
				difficulty.deserialize_and_merge_take_max(difficulty_json)
				for zone_difficulty_info in difficulty.zones_difficulty_info:
					overall_max_selectable_difficulty = int(max(overall_max_selectable_difficulty, zone_difficulty_info.max_selectable_difficulty))

	for difficulty in difficulties_unlocked:
		for zone_difficulty_info in difficulty.zones_difficulty_info:
			if zone_difficulty_info.max_selectable_difficulty < overall_max_selectable_difficulty:
				zone_difficulty_info.max_selectable_difficulty = overall_max_selectable_difficulty

	

	
	data = Utils.merge_dictionaries_take_max(data, loader_v1.data)
	for k in ["enemies_killed", "materials_collected", "trees_killed", "steps_taken", "enemies_killed_far_away"]:
		if data.has(k):
			
			data[k] = int(data[k])
