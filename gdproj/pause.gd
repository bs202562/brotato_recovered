# ============================================================
# 启动引导场景 —— 游戏真正的"第一入口"
#
# project.godot 中 run/main_scene 指向的就是 pause.tscn，
# 游戏启动后最先运行的脚本就是这个（文件名叫 pause 只是历史
# 遗留命名，和游戏内的暂停菜单无关）。
#
# 职责：
#   1. 显示启动闪屏（boot splash）
#   2. 等待存档/设置数据（ProgressData 单例）加载完成
#   3. 播放淡出动画，切换到标题界面 title_screen.tscn
#
# 场景流转：pause.tscn(本文件) → title_screen → 开局 → main.tscn(战斗)
# ============================================================
extends Control

# 启动流程状态机：就绪 → 展示闪屏 → 淡出当前画面 → 切换场景
enum State{READY, BOOT_SPLASH, HIDE_SCENE, CHANGE_SCENE}
var state = State.READY

# 存档加载完毕、可以进主菜单时置为 true（见 _on_progress_data_ready）
var ready_for_main_menu: = false


func _init() -> void :
	# Switch 类主机平台需要先开启 Joy-Con 手柄支持
	if Utils.on_nintendo_nx_or_ounce:
		OS_Seaven.set_joycon_support(true)
	# 监听存档数据加载完成信号（ProgressData 是自动加载的全局单例）
	var _ready_error = ProgressData.connect("ready", self, "_on_progress_data_ready")

func _process(_delta: float):
	# 每帧根据状态机推进启动流程
	match state:
		State.READY:
			# 等待 _draw() 完成首帧绘制后进入 BOOT_SPLASH
			pass
		State.BOOT_SPLASH:
			# 闪屏展示中，等待存档加载完成
			if ready_for_main_menu:
				state = State.HIDE_SCENE
		State.HIDE_SCENE:
			# 先应用声音设置，再播放淡出动画，动画放完才切场景
			ProgressData._apply_sounds_settings()

			$AnimationPlayer.play("start")
			yield($AnimationPlayer, "animation_finished")
			state = State.CHANGE_SCENE
		State.CHANGE_SCENE:
			# 应用全部设置（分辨率/语言等），然后进入标题界面
			ProgressData.apply_settings()
			var _error = get_tree().change_scene("res://ui/menus/title_screen/title_screen.tscn")


func _draw():
	# 首帧真正画出来之后才进入闪屏状态，保证玩家能看到闪屏画面
	if state == State.READY:
		state = State.BOOT_SPLASH


func _on_progress_data_ready() -> void :
	# 存档加载完成回调：只要不是"云存档全部损坏"的致命情况就放行
	if not ProgressData.load_status in [LoadStatus.CORRUPTED_ALL_SAVES_EPIC, LoadStatus.CORRUPTED_ALL_SAVES_STEAM]:
		ready_for_main_menu = true
