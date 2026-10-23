# 本地合作模式服务：管理玩家与输入设备绑定、长按加入流程、玩家配色及按键图标。
# 同时提供多人敌人强度参数和材料价值补正；输入动作由 InputService 按设备生成。
# 阅读主线：_input → _process → _add_player → connected_players_updated。
extends Node

# 玩家列表变化时通知相关界面；进度信号用于刷新长按加入提示。
signal connected_players_updated(connected_players)
signal connection_progress_updated(progress_values)

# 每增加一名合作玩家时，敌人数量、生命和伤害的附加比例；具体值由场景资源配置。
export (float, 0.0, 1.0, 0.01) var additional_enemies_per_coop_player: = 0.0
export (float, 0.0, 1.0, 0.01) var additional_enemy_health_per_coop_player: = 0.0
export (float, 0.0, 1.0, 0.01) var additional_enemy_damage_per_coop_player: = 0.0

# 按设备类型配置确认、选择、详情、扳机和合作禁用操作的提示图标。
export (Texture) var keyboard_ui_accept_icon
export (Texture) var gamepad_xbox_ui_accept_icon
export (Texture) var gamepad_playstation_ui_accept_icon
export (Texture) var gamepad_switch_ui_accept_icon
export (Texture) var keyboard_ui_select_icon
export (Texture) var gamepad_xbox_ui_select_icon
export (Texture) var gamepad_playstation_ui_select_icon
export (Texture) var gamepad_switch_ui_select_icon
export (Texture) var keyboard_ui_info_icon
export (Texture) var gamepad_xbox_ui_info_icon
export (Texture) var gamepad_playstation_ui_info_icon
export (Texture) var gamepad_switch_ui_info_icon
export (Texture) var gamepad_ltrigger_icon
export (Texture) var gamepad_rtrigger_icon
export (Texture) var keyboard_ui_coop_ban_icon
export (Texture) var gamepad_xbox_ui_coop_ban_icon
export (Texture) var gamepad_playstation_ui_coop_ban_icon
export (Texture) var gamepad_switch_ui_coop_ban_icon
export (Texture) var gamepad_switch_ltrigger_icon
export (Texture) var gamepad_switch_rtrigger_icon
export (Texture) var gamepad_playstation_ltrigger_icon
export (Texture) var gamepad_playstation_rtrigger_icon
export (Texture) var gamepad_switch_pos_down_icon
export (Texture) var gamepad_switch_pos_up_icon
export (Texture) var gamepad_switch_pos_right_icon
export (Texture) var gamepad_switch_pos_left_icon
export (Texture) var gamepad_switch_sl_icon
export (Texture) var gamepad_switch_sr_icon

# 按玩家序号 0～3 分配的基础颜色，用于区分各玩家的界面。
export (Array, Color) var player_colors: = [
	Color("a1fced"), 
	Color("f2ad87"), 
	Color("a9fca1"), 
	Color("fcf08f")
]


# InputService 为逻辑设备 0～7 生成带后缀的动作，例如 ui_accept_6。
# 原始设备 0 的手柄与键盘分别映射为 6、7，避免共用同一个输入标识。
const REMAP_END: = 8
const GAMEPAD_REMAPPED_DEVICE_ID: = 6
const KEYBOARD_REMAPPED_DEVICE_ID: = 7



# UI 槽位上限与平台实际人数上限分开；实际人数使用 get_max_players()。
const UI_MAX_PLAYER_COUNT: = 4
# 调试模式用额外逻辑设备模拟多套键盘操作。
const FIRST_DEBUG_DEVICE_ID: = 8
const DEBUG_DEVICE_COUNT: = 4
# 持续按住确认键 0.7 秒后加入。
const HOLD_DURATION: = 0.7

enum PlayerType{KEYBOARD_AND_MOUSE, GAMEPAD_XBOX, GAMEPAD_PLAYSTATION, GAMEPAD_SWITCH}


# 每条玩家记录为 [重映射后的设备 ID, PlayerType]，数组下标就是 player_index。
var connected_players: = []
# 当前等待加入的长按进度列表，按进度降序排列。
var connection_progress: = []
# 业务层是否允许加入；菜单还需通过 set_process_input() 控制输入回调。
var listening_for_inputs: bool = false

# 设备 ID → 已持续按住确认键的秒数；松开、已绑定或不允许加入时取消。
var _hold_timers: = {}
# 保存场景配置的初始难度参数，供 clear() 恢复。
var _initial_additional_enemies: float
var _initial_additional_enemies_health: float
var _initial_additional_enemies_damage: float
# 平台强制手柄时，is_player_using_gamepad() 跳过玩家记录判断。
var force_gamepad: bool = false


# 初始化平台输入限制、监听手柄插拔，并保存合作难度参数的初始值。
func _ready() -> void :
	if Utils.is_on_console() and not Utils.on_gdk:
		force_gamepad = true

	var _err = Input.connect("joy_connection_changed", self, "_on_Input_joy_connection_changed")
	set_process_input(false)

	_initial_additional_enemies = additional_enemies_per_coop_player
	_initial_additional_enemies_health = additional_enemy_health_per_coop_player
	_initial_additional_enemies_damage = additional_enemy_damage_per_coop_player


# 接收加入操作并启动长按计时；是否允许加入由 _process 再检查。
func _input(event: InputEvent) -> void :
	var device_to_add = event.device
	if event.device == 0:
		
		device_to_add = GAMEPAD_REMAPPED_DEVICE_ID if event is InputEventJoypadButton else KEYBOARD_REMAPPED_DEVICE_ID

	# 多键盘调试模式把加入尝试分配给下一个空闲的调试设备。
	if event is InputEventKey and DebugService.coop_multiple_keyboard_inputs:
		var debug_device = _get_next_free_debug_device()
		if debug_device >= 0:
			device_to_add = debug_device

	if Utils.on_nintendo_nx_or_ounce:
		
		pass
	else:
		if event.is_action_pressed("ui_accept_%s" % device_to_add) and not _hold_timers.has(device_to_add):
			
			_hold_timers[device_to_add] = 0.0
			set_process(true)



# 累计各设备的确认键长按时间，达到阈值后识别输入类型并加入玩家。
func _process(delta: float) -> void :
	var max_timer_before: = 0.0
	for timer in _hold_timers:
		max_timer_before = max(max_timer_before, timer)

	# 退出加入阶段或人数已满时，取消全部等待中的长按。
	if not listening_for_inputs or not _can_add_new_device():
		_hold_timers.clear()

	for device in _hold_timers.keys():
		if not Input.is_action_pressed("ui_accept_%s" % device) or is_device_assigned(device):
			var _erased = _hold_timers.erase(device)
			continue
		_hold_timers[device] += delta
		if _hold_timers[device] < HOLD_DURATION:
			continue
		
		var _erased = _hold_timers.erase(device)
		
		_update_connection_progress()
		# 查询系统手柄名称前还原为物理设备 ID；玩家记录仍保存逻辑设备 ID。
		var unmapped_device = 0 if device == GAMEPAD_REMAPPED_DEVICE_ID or device == KEYBOARD_REMAPPED_DEVICE_ID else device
		var joy_name = Input.get_joy_name(unmapped_device)
		var joy_name_components = joy_name.to_lower().split(" ")

		
		# 主机按平台确定输入类型；其他平台按设备名识别，未知手柄默认使用 Xbox 图标。
		if Utils.on_nintendo_nx_or_ounce:
			_add_player(device, PlayerType.GAMEPAD_SWITCH)
		elif Utils.on_gdk:
			if device == KEYBOARD_REMAPPED_DEVICE_ID or joy_name.empty():
				_add_player(device, PlayerType.KEYBOARD_AND_MOUSE)
			else:
				_add_player(device, PlayerType.GAMEPAD_XBOX)
		elif Utils.on_playstation:
			_add_player(device, PlayerType.GAMEPAD_PLAYSTATION)
		else:
			if device == KEYBOARD_REMAPPED_DEVICE_ID or joy_name.empty():
				_add_player(device, PlayerType.KEYBOARD_AND_MOUSE)
			elif "ps4" in joy_name_components or "ps5" in joy_name_components or "playstation" in joy_name_components or "dualsense" in joy_name_components:
				_add_player(device, PlayerType.GAMEPAD_PLAYSTATION)
			elif "nintendo" in joy_name_components or "switch" in joy_name_components:
				_add_player(device, PlayerType.GAMEPAD_SWITCH)
			else:
				_add_player(device, PlayerType.GAMEPAD_XBOX)
		# 每帧最多加入一名玩家，其余设备的计时留到下一帧处理。
		break

	_update_connection_progress()
	if _hold_timers.empty():
		set_process(false)

# 材料补偿系数：只应用理论补偿量的 80%。
const ADDITIONAL_MATERIALS_FACTOR: = 0.8

# 返回平台实际允许的玩家数：Nintendo NX 为 2，其余分支为 4。
func get_max_players():
	if Utils.on_nintendo_nx: return 2
	return 4

# 计算每位额外玩家带来的材料价值增量，抵消部分敌人数量增长的影响。
func get_additional_materials_per_coop_player() -> float:
	var nb_players = RunData.get_player_count()

	if nb_players == 1:
		return 0.0

	# nb_enemies 是相对单人的敌人数量倍率；按人数/敌人倍率计算补偿，再均摊到额外玩家。
	var nb_enemies = 1.0 + (additional_enemies_per_coop_player * (nb_players - 1))
	return (((nb_players / nb_enemies) - 1.0) / (nb_players - 1)) * ADDITIONAL_MATERIALS_FACTOR


# 返回全队材料价值的额外比例，不含基础值；调用方按 value += value * factor 使用。
func get_coop_materials_factor() -> float:
	return get_additional_materials_per_coop_player() * (RunData.get_player_count() - 1)


# 结束加入监听、清空玩家，并恢复启动时保存的三项合作难度参数。
func clear() -> void :
	listening_for_inputs = false
	clear_coop_players()

	additional_enemies_per_coop_player = _initial_additional_enemies
	additional_enemy_health_per_coop_player = _initial_additional_enemies_health
	additional_enemy_damage_per_coop_player = _initial_additional_enemies_damage


# 清空已加入玩家并通知界面；不在这里重置难度参数或长按计时。
func clear_coop_players() -> void :
	connected_players.clear()
	emit_signal("connected_players_updated", connected_players)


# 直接修改传入的样式资源，使边框和背景体现玩家颜色；需要独立样式时由调用方先复制。
func change_stylebox_for_player(stylebox: StyleBox, player_index: int) -> void :
	if stylebox is StyleBoxFlat:
		var background_value = stylebox.bg_color.v
		stylebox.border_color = get_player_color(player_index, 1)

		var player_color = get_player_color(player_index, clamp(background_value, 0.2, 0.75))
		# 混合玩家色时保留原背景透明度。
		var a = stylebox.bg_color.a
		stylebox.bg_color = stylebox.bg_color.linear_interpolate(player_color, 0.7)
		stylebox.bg_color.a = a

	elif stylebox is StyleBoxTexture:
		stylebox.modulate_color = get_player_color(player_index, 1)


# 按玩家序号取配色，提高饱和度，再用 value 缩放明度；调用方需保证序号有效。
func get_player_color(player_index: int, value: = 1.0) -> Color:
	var c = player_colors[player_index]
	c.s = min(c.s + 0.5, 1.0)
	c.v = min(c.v * value, 1.0)
	return c



# 取得玩家绑定的逻辑设备 ID；玩家序号无效时返回 -1。
func get_remapped_player_device(player_index: int) -> int:
	if player_index < 0 or player_index >= len(connected_players):
		return - 1
	return connected_players[player_index][0]


# 判断玩家是否使用手柄；平台强制手柄时优先返回 true。
func is_player_using_gamepad(player_index: int) -> bool:
	if force_gamepad:
		return true

	if player_index < 0 or player_index >= len(connected_players):
		return false

	return get_player_input_type(player_index) != PlayerType.KEYBOARD_AND_MOUSE


# 获取玩家的操作提示图标；没有有效玩家记录时使用 UIService 当前输入类型。
func get_player_key_texture(action: String, player_index: int) -> Texture:
	if player_index < 0 or player_index >= len(connected_players):
		var device = UIService.current_device
		var input_style = OS_Seaven.get_controller_style(player_index)
		return get_input_type_key_texture(action, device, input_style)
	var input_type = get_player_input_type(player_index)
	var input_style = OS_Seaven.get_controller_style(player_index)
	return get_input_type_key_texture(action, input_type, input_style)


# 按动作、输入类型和平台控制器样式选择图标；不支持的组合返回 null。
# Switch 样式值 4、5 使用位置按钮及 SL/SR 图标，其他样式使用常规图标。
func get_input_type_key_texture(action: String, input_type: int, input_style: int) -> Texture:
	if action == "ui_accept":
		match input_type:
			PlayerType.KEYBOARD_AND_MOUSE:
				return keyboard_ui_accept_icon
			PlayerType.GAMEPAD_XBOX:
				return gamepad_xbox_ui_accept_icon
			PlayerType.GAMEPAD_PLAYSTATION:
				return gamepad_playstation_ui_accept_icon
			PlayerType.GAMEPAD_SWITCH:
				if input_style == 4 or input_style == 5:
					return gamepad_switch_pos_right_icon
				else:
					return gamepad_switch_ui_accept_icon
	elif action == "ui_select":
		match input_type:
			PlayerType.KEYBOARD_AND_MOUSE:
				return keyboard_ui_select_icon
			PlayerType.GAMEPAD_XBOX:
				return gamepad_xbox_ui_select_icon
			PlayerType.GAMEPAD_PLAYSTATION:
				return gamepad_playstation_ui_select_icon
			PlayerType.GAMEPAD_SWITCH:
				if input_style == 4 or input_style == 5:
					return gamepad_switch_pos_up_icon
				else:
					return gamepad_switch_ui_select_icon
	elif action == "ui_info":
		match input_type:
			PlayerType.KEYBOARD_AND_MOUSE:
				return keyboard_ui_info_icon
			PlayerType.GAMEPAD_XBOX:
				return gamepad_xbox_ui_info_icon
			PlayerType.GAMEPAD_PLAYSTATION:
				return gamepad_playstation_ui_info_icon
			PlayerType.GAMEPAD_SWITCH:
				if input_style == 4 or input_style == 5:
					return gamepad_switch_pos_left_icon
				else:
					return gamepad_switch_ui_info_icon
	elif action == "ltrigger":
		if input_type != PlayerType.KEYBOARD_AND_MOUSE:
			match input_type:
				PlayerType.GAMEPAD_XBOX:
					return gamepad_ltrigger_icon
				PlayerType.GAMEPAD_PLAYSTATION:
					return gamepad_playstation_ltrigger_icon
				PlayerType.GAMEPAD_SWITCH:
					if input_style == 4 or input_style == 5:
						return gamepad_switch_sl_icon
					else:
						return gamepad_switch_ltrigger_icon
	elif action == "rtrigger":
		if input_type != PlayerType.KEYBOARD_AND_MOUSE:
			match input_type:
				PlayerType.GAMEPAD_XBOX:
					return gamepad_rtrigger_icon
				PlayerType.GAMEPAD_PLAYSTATION:
					return gamepad_playstation_rtrigger_icon
				PlayerType.GAMEPAD_SWITCH:
					if input_style == 4 or input_style == 5:
						return gamepad_switch_sr_icon
					else:
						return gamepad_switch_rtrigger_icon
	elif action == "ui_coop_ban":
		match input_type:
			PlayerType.KEYBOARD_AND_MOUSE:
				return keyboard_ui_coop_ban_icon
			PlayerType.GAMEPAD_XBOX:
				return gamepad_xbox_ui_coop_ban_icon
			PlayerType.GAMEPAD_PLAYSTATION:
				return gamepad_playstation_ui_coop_ban_icon
			PlayerType.GAMEPAD_SWITCH:
				return gamepad_switch_ui_coop_ban_icon
	return null


# 读取玩家记录中的 PlayerType；本方法不检查 player_index 是否越界。
func get_player_input_type(player_index: int) -> int:
	return connected_players[player_index][1]


# 追加设备与输入类型，数组位置即玩家序号；避免重复设备，人数上限由外部流程检查。
func _add_player(device: int, player_type: int) -> void :
	if is_device_assigned(device):
		return
	print("adding player device " + str(device) + " at place " + str(len(connected_players)))
	connected_players.push_back([device, player_type])
	emit_signal("connected_players_updated", connected_players)


# 按逻辑设备 ID 移除玩家并通知界面；后续玩家的数组序号会前移。
func _remove_player(device: int) -> void :
	if not is_device_assigned(device):
		print("can't find player to remove with device " + str(device))
		return

	for i in len(connected_players):
		if connected_players[i][0] == device:
			print("removing player " + str(i))
			connected_players.remove(i)
			emit_signal("connected_players_updated", connected_players)
			return

# 把长按秒数转换为 0～1 的进度，并从大到小排列，供加入提示显示。
# 排序后只保留进度值，不再对应固定的设备 ID 或玩家序号。
func _update_connection_progress() -> void :
	connection_progress = _hold_timers.values()
	
	connection_progress.sort()
	connection_progress.invert()
	for i in connection_progress.size():
		connection_progress[i] = min(connection_progress[i] / HOLD_DURATION, 1.0)
	emit_signal("connection_progress_updated", connection_progress)


# 判断逻辑设备是否已经绑定到某位玩家。
func is_device_assigned(device: int) -> bool:
	for player in connected_players:
		if player[0] == device:
			return true

	return false


# 检查已加入人数是否低于当前平台上限。
func _can_add_new_device() -> bool:
	return len(connected_players) < get_max_players()


# 寻找尚未绑定的调试设备 ID（8～11），全部占用时返回 -1。
func _get_next_free_debug_device() -> int:
	for device_id in range(FIRST_DEBUG_DEVICE_ID, FIRST_DEBUG_DEVICE_ID + DEBUG_DEVICE_COUNT):
		if not is_device_assigned(device_id):
			return device_id

	return - 1


# 仅在允许加入的阶段处理手柄断开并移除玩家；连接事件和非监听阶段不在这里处理。
func _on_Input_joy_connection_changed(device: int, connected: bool) -> void :
	
	if connected or not listening_for_inputs:
		return
	if device == 0:
		device = GAMEPAD_REMAPPED_DEVICE_ID
	for player_index in connected_players.size():
		var player = connected_players[player_index]
		if player[0] != device:
			continue
		connected_players.remove(player_index)
		emit_signal("connected_players_updated", connected_players)
		break
