# ============================================================
# 主机平台适配层（"Seaven"）的 PC 版存根 (stub)
#
# 主机版(Switch/PS/Xbox)构建时此文件会被真正的实现替换；
# PC 版只需要保证这些接口存在且返回合理的默认值。
#
# 4.x 移植说明：Godot 3 的解析器不会静态检查 autoload 的方法调用，
# 所以原 PC 版存根只实现了 2 个方法也能通过；Godot 4 会在解析期
# 检查所有 OS_Seaven.xxx() 调用，因此这里把全部被调用的接口补成
# 空实现。所有调用点都有 Utils.is_on_console() 等平台判断守护，
# PC 上这些函数几乎不会被真正执行。
# ============================================================
extends Node

func get_controller_style(style_id: int):
	return 0

func is_in_editor_mode():
	return false

# ---------- 以下为 4.x 移植时补全的空实现 ----------

func set_joycon_support(_enabled: bool) -> void:
	pass

func set_fast_cpu_mode(_enabled: bool) -> void:
	pass

func set_vsync_interval(_interval: int) -> void:
	pass

func get_max_controller_count() -> int:
	return 8

func set_max_controller_count(_count: int) -> void:
	pass

func set_min_controller_count(_count: int) -> void:
	pass

func get_controller_count() -> int:
	return Input.get_connected_joypads().size()

func show_controller_applet(_min_players: int, _max_players: int) -> bool:
	return true

func set_controller_color(_index: int, _color = null) -> void:
	pass

func has_controller_style_maybe_changed() -> bool:
	return false

func has_keyboard() -> bool:
	return true

func get_gamertag() -> String:
	return ""

func unlock_achievement(_id) -> void:
	pass

func show_product_store(_id = null) -> void:
	pass

func has_dlc_updates() -> bool:
	return false

# 活动(Activity)相关：PS5 平台功能
func start_activity(_id) -> void:
	pass

func end_activity(_id = null, _completed = false) -> void:
	pass

func terminate_activity(_id = null) -> void:
	pass

func get_pending_activity() -> String:
	return ""

# 直播联机(Streamplay)相关
func start_streamplay(_internet: bool, _config = null) -> int:
	return 0

func stop_streamplay() -> void:
	pass

func check_streamplay_state(_state = null):
	return 0

func get_date() -> Dictionary:
	return Time.get_date_dict_from_system()
