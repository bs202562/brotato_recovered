# ============================================================
# 标题界面（主菜单）—— 启动闪屏之后进入的第一个交互界面
#
# 由 pause.tscn（启动引导）加载进来。职责：
#   1. 加载并展示主视觉背景（keyart，可在设置里选固定/随机）
#   2. 根据存档决定是否显示"继续游戏"按钮
#   3. 重置本局运行数据 RunData，播放标题音乐
#   4. 弹出 Mod 更新警告 / 测试版存档警告等公告弹窗
# 点击"开始"后由菜单子页面（title_screen_menus 等）走
# 选角色 → 选武器 → 选难度的流程，最终进入 main.tscn 战斗场景。
# ============================================================
class_name TitleScreen
extends Control

# ---------- 场景节点引用 ----------
@onready var _menus: Control = $"%Menus"  # 菜单页面管理器（主菜单/选角等页面切换）
@onready var _main_menu: VBoxContainer = $"%MainMenu"  # 主菜单按钮列（开始/继续/设置/退出…）
@onready var _animated_background_container: Control = $"%AnimatedBackgroundContainer"  # 动态背景容器
@onready var _attenuate_background: ColorRect = $"%AttenuateBackground"  # 进入子页面时压暗背景的遮罩
@onready var _pop_up_mods_update_warning: PopupAnouncement = $"%popup_mods_update_warning"  # Mod 更新警告弹窗
@onready var _pop_up_beta_save_warning: PopupAnouncement = $"%popup_beta_save_warning"  # 测试版存档警告弹窗

var current_keyart: TitleScreenBackgroundData  # 当前使用的主视觉背景数据

func _ready() -> void :

	# DLC 启用/停用时刷新背景（不同 DLC 有不同主视觉）
	var _e = ProgressData.connect("dlc_activated", Callable(self, "on_dlc_changed"))
	_e = ProgressData.connect("dlc_deactivated", Callable(self, "on_dlc_changed"))

	ProgressData.connect("change_keyart", Callable(self, "reload_background"))

	reload_background()
	update_continue_button()
	update_profile_button()

	# 主机平台不显示"退出游戏"按钮（GDK 桌面版除外）
	if not Utils.is_on_console() or Utils.on_gdk_desktop:
		_main_menu.quit_button.show()
		_main_menu.quit_button.activate()
	else:
		_main_menu.quit_button.hide()
		_main_menu.quit_button.disable()

	# 回到标题界面 = 一局结束/放弃，重置本局运行数据
	RunData.current_zone = 0
	RunData.reset()

	# reload_music 为 false 说明音乐已在播放（如从游戏内返回），跳过一次重播
	if RunData.reload_music:
		MusicManager.play(0)
	else:
		RunData.reload_music = true

	var _switched_result: = _menus.connect("menu_page_switched", Callable(self, "on_menu_page_switched"))
	_main_menu.init()
	# Switch 平台：限制为单手柄并弹出手柄配对界面
	if Utils.on_nintendo_nx_or_ounce and OS_Seaven.get_max_controller_count() > 1:
		OS_Seaven.set_max_controller_count(1)
		OS_Seaven.show_controller_applet(1, 1)

	# 需要时弹出 Mod 更新 / 测试版存档警告
	if ProgressData.should_show_mod_warning_popup():
		_pop_up_mods_update_warning.popup_announcement()

	if ProgressData.show_main_title_beta_save_warning_popup:
		_pop_up_beta_save_warning.popup_announcement()


func on_dlc_changed(_dlc_id: String) -> void :
	reload_background()

# 有可恢复的存档（且所需 DLC 有效、非直播联机模式）才显示"继续"按钮
func update_continue_button():
	if ProgressData.saved_run_state.has_run_state and ProgressData.check_dlc_valid_for_saved_run_state() and not ProgressData.saved_run_state.get("is_streamplay_run", false):
		_main_menu.continue_button.show()
		_main_menu.continue_button.activate()
	else:
		_main_menu.continue_button.hide()
		_main_menu.continue_button.disable()

# 显示当前存档档位编号（档案 1/2/3…）
func update_profile_button():
	_main_menu.profile_button.text = Text.text("MENU_PROFILE", [str(ProgressData.current_profile_id + 1)])

func sort_by_priority(a, b):
	return a.index_priority < b.index_priority

# 重新加载标题背景（keyart）：
#   设置值 0 = 按优先级取最高且可用的背景（通常是最新 DLC 的）
#   设置值 1 = 随机
#   其他值   = 指定第 N 张背景
func reload_background() -> void :
	for child in _animated_background_container.get_children():
		child.queue_free()

	var key_art_mode: int = ProgressData.settings.main_screen_keyart
	if key_art_mode - 2 >= ItemService.title_screen_backgrounds.size():
		key_art_mode = 0

	match key_art_mode:
		0:
			ItemService.title_screen_backgrounds.sort_custom(Callable(self, "sort_by_priority"))
			for i in range(ItemService.title_screen_backgrounds.size() - 1, - 1, - 1):
				var screen = ItemService.title_screen_backgrounds[i]
				if screen.is_available():
					current_keyart = screen
					break
		1:
			current_keyart = ItemService.title_screen_backgrounds.pick_random()
		_:
			current_keyart = ItemService.title_screen_backgrounds[key_art_mode - 2]

	var instance = current_keyart.scene.instantiate()
	_animated_background_container.add_child(instance)
	_main_menu.reload_logo(current_keyart)


# 菜单页面切换：离开主菜单时压暗背景；回到主菜单时刷新"继续"按钮等状态
func on_menu_page_switched(_from: Control, to: Control) -> void :
	if to != _main_menu:
		_attenuate_background.show()
	else:
		_attenuate_background.hide()
		update_continue_button()
		update_profile_button()
