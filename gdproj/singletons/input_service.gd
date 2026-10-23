# 输入服务：管理手柄 UI 连发、设备专用动作、焦点变化及鼠标显示。
# 映射主线：_ready → _copy_device_actions；连发主线：_process → _process_input_timers → _emulate_action。
extends Node

signal game_lost_focus
signal game_regained_focus

# 连发扫描的物理设备编号范围为 0～7。
const MAX_DEVICE_COUNT: = 8


var using_gamepad = false
# 轴输入转为 UI 动作的阈值，独立于 InputMap 中每个动作的死区。
var joystick_deadzone: = 0.5

# 首次连发延迟与后续间隔，单位为秒。
var _echo_delay: = 0.3
var _echo_interval: = 0.09
# 物理设备 ID → FixedTimer；方向键和摇杆分别计时，不按单个方向分开。
var _dpad_timers: = {}
var _joystick_timers: = {}

# 防止控制器数量持续不匹配时重复请求暂停。
var _switch_asked_pause: = false
# 仅阻止本服务 _process 中的模拟输入，不是全局禁用 Input。
var _disable_input: = false


# 暂停时仍处理输入服务，并根据设置重建输入映射、启动手柄方向连发。
func _ready() -> void :
	pause_mode = Node.PAUSE_MODE_PROCESS
	var _input_connect = Input.connect("joy_connection_changed", self, "on_joy_connection_changed")

	if ProgressData.settings.movement_with_gamepad:
		enable_gamepad_movement()
	else:
		disable_gamepad_movement()

	set_gamepad_echo_processing(true)


# 根据本次输入切换鼠标显示及 using_gamepad；报告窗口和多人合作模式有优先处理分支。
func _input(event: InputEvent) -> void :
	
	if BugReporter.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	if RunData.is_coop_run and RunData.get_player_count() > 1:
		
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		return

	var is_gamepad_input = event is InputEventJoypadButton or Utils.is_valid_joypad_motion_event(event)
	var is_keyboard_input = event is InputEventKey
	var is_mouse_input = event is InputEventMouseMotion or event is InputEventMouseButton

	if is_gamepad_input or is_keyboard_input:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	elif is_mouse_input:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_gamepad_input:
		using_gamepad = true
	elif is_keyboard_input or is_mouse_input:
		using_gamepad = false


# 重载项目输入配置后，移除指定基础移动/右摇杆动作的手柄事件。
# 带设备后缀的动作已提前复制，不在此处移除；部分主机平台强制启用手柄移动。
func disable_gamepad_movement() -> void :
	if Utils.on_console and not Utils.on_gdk_desktop:
		enable_gamepad_movement()
		return

	InputMap.load_from_globals()
	_copy_device_actions()

	for action in InputMap.get_actions():
		var actions_to_disable: = ["button_move_left", "button_move_right", "button_move_up", "button_move_down", 
			"analog_move_left", "analog_move_right", "analog_move_up", "analog_move_down", 
			"rjoy_left", "rjoy_right", "rjoy_up", "rjoy_down"]

		if action in actions_to_disable:
			for input_event in InputMap.get_action_list(action):
				if input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion:
					InputMap.action_erase_event(action, input_event)


# 恢复项目默认输入配置，再生成各设备专用动作。
func enable_gamepad_movement() -> void :
	InputMap.load_from_globals()
	_copy_device_actions()


# 手柄插拔后重新判断是否需要逐帧处理；断开或指定 Nintendo 平台的插拔会发出失焦信号。
func on_joy_connection_changed(_device: int, connected: bool) -> void :
	set_gamepad_echo_processing(true)
	
	if Utils.on_nintendo_nx_or_ounce or not connected:
		emit_signal("game_lost_focus")


# 响应窗口焦点变化，按设置静音、恢复音量及暂停模拟输入，并通知其他节点。
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT:
		if ProgressData.settings.mute_on_focus_lost:
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(0.0))
		if ProgressData.settings.on_lost_focus == 2:
			_disable_input = true
		emit_signal("game_lost_focus")
	elif what == MainLoop.NOTIFICATION_WM_FOCUS_IN:
		if ProgressData.settings.has("volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(ProgressData.settings.volume.master ))
		_disable_input = false
		emit_signal("game_regained_focus")


# 仅在允许处理且存在已连接手柄时启用 _process。
func set_gamepad_echo_processing(enable: bool) -> void :
	if enable and Input.get_connected_joypads().size() > 0:
		set_process(true)
	else:
		set_process(false)


# 清理已松开的方向输入计时，推进按住连发，并检查 Nintendo 合作模式的控制器人数。
func _process(delta: float) -> void :
	if _disable_input:
		return
	
	for device in _dpad_timers.keys():
		var is_any_input_pressed = false
		for input in _d_pad_button_range():
			if _is_input_pressed(device, input, "button"):
				is_any_input_pressed = true
				break
		if not is_any_input_pressed:
			var _erased = _dpad_timers.erase(device)

	for device in _joystick_timers.keys():
		var is_any_input_pressed = false
		for input in [JOY_AXIS_0, JOY_AXIS_1]:
			if _is_input_pressed(device, input, "axis"):
				is_any_input_pressed = true
				break
		if not is_any_input_pressed:
			var _erased = _joystick_timers.erase(device)

	_process_input_timers(delta, _d_pad_button_range(), funcref(self, "_on_dpad_timer_timeout"), "button")
	_process_input_timers(delta, [JOY_AXIS_0, JOY_AXIS_1], funcref(self, "_on_joystick_timer_timeout"), "axis")

	if Utils.on_nintendo_nx_or_ounce:
		
		if RunData.is_coop_run and (OS.get_controller_count() != RunData.get_player_count()):
			if _switch_asked_pause == false:
				_switch_asked_pause = true
				emit_signal("game_lost_focus")
		else:
			_switch_asked_pause = false


# 每个设备、每类输入共用一个计时器：首次等待 _echo_delay，之后按 _echo_interval 连发。
func _process_input_timers(delta: float, input_range: Array, timeout_callback: FuncRef, input_type: String) -> void :
	var timers = _dpad_timers if input_type == "button" else _joystick_timers

	
	for device in timers.keys():
		var timer = timers[device]
		timer.try_advance(delta)
		if not timer.completed():
			continue
		timeout_callback.call_func(device)
		var _erased = timers.erase(device)
		for input in input_range:
			if not _is_input_pressed(device, input, input_type):
				continue
			
			timer.wait_time = _echo_interval
			timer.start()
			timers[device] = timer
			break

	
	for device in MAX_DEVICE_COUNT:
		if timers.has(device):
			continue
		for input in input_range:
			if _is_input_pressed(device, input, input_type):
				var timer: = FixedTimer.new()
				timer.wait_time = _echo_delay
				timer.start()
				timers[device] = timer
				# 摇杆首次超过死区时立即导航，之后才等待连发计时。
				if input_type == "axis":
					
					timeout_callback.call_func(device)
				break


# 判断物理手柄按钮是否按下，或轴偏移是否超过本服务的摇杆死区。
func _is_input_pressed(device: int, input, input_type: String) -> bool:
	if input_type == "axis":
		return abs(Input.get_joy_axis(device, input)) > joystick_deadzone
	else:
		return Input.is_joy_button_pressed(device, input)


# 返回方向键按钮编号 12～15，对应上、下、左、右。
func _d_pad_button_range() -> Array:
	return range(12, 16)


# 为仍按住的方向键生成 UI 导航动作；多个方向可以在同次回调中触发。
func _on_dpad_timer_timeout(device: int) -> void :
	_emulate_action(device, 12, "ui_up")
	_emulate_action(device, 13, "ui_down")
	_emulate_action(device, 14, "ui_left")
	_emulate_action(device, 15, "ui_right")


# 将左摇杆映射为 UI 导航；横轴优先，横轴未超过死区才处理纵轴。
func _on_joystick_timer_timeout(device: int) -> void :
	if abs(Input.get_joy_axis(device, JOY_AXIS_0)) > joystick_deadzone:
		_emulate_action(device, JOY_AXIS_0, "ui_right" if Input.get_joy_axis(device, JOY_AXIS_0) > 0 else "ui_left")
	elif abs(Input.get_joy_axis(device, JOY_AXIS_1)) > joystick_deadzone:
		_emulate_action(device, JOY_AXIS_1, "ui_down" if Input.get_joy_axis(device, JOY_AXIS_1) > 0 else "ui_up")


# 注入一个按下状态的 UI 动作事件；已绑定合作玩家的设备使用带设备后缀的动作。
func _emulate_action(device: int, input, action: String) -> void :
	var input_type = "axis" if input in [JOY_AXIS_0, JOY_AXIS_1] else "button"
	if not _is_input_pressed(device, input, input_type):
		return

	# 物理手柄 0 映射为逻辑设备 6；未绑定玩家时发送不带后缀的通用动作。
	var remapped_device = device if device > 0 else CoopService.GAMEPAD_REMAPPED_DEVICE_ID
	var suffix = ("_%s" % remapped_device) if CoopService.is_device_assigned(remapped_device) else ""

	var a = InputEventAction.new()
	a.action = action + suffix
	a.device = device
	a.pressed = true
	Input.parse_input_event(a)


# 复制项目中的手柄按钮、轴和键盘动作，生成 action_设备ID 形式的多人输入映射。
# 同时配置编辑器报告快捷键，以及调试模式下的四套键盘操作。
func _copy_device_actions():
	_set_bug_report_key()

	var action_names = InputMap.get_actions()
	for action_name in action_names:
		var action_events = InputMap.get_action_list(action_name)
		var deadzone = InputMap.action_get_deadzone(action_name)
		for event in action_events:
			
			
			

			if event is InputEventJoypadButton:
				for remapped_device in range(0, CoopService.REMAP_END):
					var new_event = InputEventJoypadButton.new()
					new_event.device = 0 if remapped_device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID else remapped_device
					new_event.button_index = event.button_index
					new_event.pressed = event.pressed
					add_action(action_name, remapped_device, deadzone, new_event)

			elif event is InputEventJoypadMotion:
				for remapped_device in range(0, CoopService.REMAP_END):
					var new_event = InputEventJoypadMotion.new()
					new_event.device = 0 if remapped_device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID else remapped_device
					new_event.axis = event.axis
					new_event.axis_value = event.axis_value
					add_action(action_name, remapped_device, deadzone, new_event)

			elif event is InputEventKey:
				for remapped_device in range(0, CoopService.REMAP_END):
					var device = 0 if remapped_device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID else remapped_device
					add_key_action(action_name, remapped_device, device, event)

	# 用 WASD、TFGH、IJKL 和方向键模拟四个设备，同时补充已有的 ui/move 动作。
	if DebugService.coop_multiple_keyboard_inputs:
		var debug_device_id = CoopService.FIRST_DEBUG_DEVICE_ID
		var debug_key_mappings = {
			KEY_W: [debug_device_id, "up"], 
			KEY_A: [debug_device_id, "left"], 
			KEY_S: [debug_device_id, "down"], 
			KEY_D: [debug_device_id, "right"], 
			KEY_E: [debug_device_id, "accept"], 
			KEY_Q: [debug_device_id, "pause"], 
			KEY_Z: [debug_device_id, "cancel"], 
			KEY_X: [debug_device_id, "info"], 
			KEY_C: [debug_device_id, "select"], 
			KEY_T: [debug_device_id + 1, "up"], 
			KEY_F: [debug_device_id + 1, "left"], 
			KEY_G: [debug_device_id + 1, "down"], 
			KEY_H: [debug_device_id + 1, "right"], 
			KEY_Y: [debug_device_id + 1, "accept"], 
			KEY_R: [debug_device_id + 1, "pause"], 
			KEY_V: [debug_device_id + 1, "cancel"], 
			KEY_B: [debug_device_id + 1, "info"], 
			KEY_N: [debug_device_id + 1, "select"], 
			KEY_I: [debug_device_id + 2, "up"], 
			KEY_J: [debug_device_id + 2, "left"], 
			KEY_K: [debug_device_id + 2, "down"], 
			KEY_L: [debug_device_id + 2, "right"], 
			KEY_O: [debug_device_id + 2, "accept"], 
			KEY_U: [debug_device_id + 2, "pause"], 
			KEY_M: [debug_device_id + 2, "cancel"], 
			KEY_COMMA: [debug_device_id + 2, "info"], 
			KEY_PERIOD: [debug_device_id + 2, "select"], 
			KEY_UP: [debug_device_id + 3, "up"], 
			KEY_LEFT: [debug_device_id + 3, "left"], 
			KEY_DOWN: [debug_device_id + 3, "down"], 
			KEY_RIGHT: [debug_device_id + 3, "right"], 
			KEY_PAGEUP: [debug_device_id + 3, "accept"], 
			KEY_INSERT: [debug_device_id + 3, "pause"], 
			KEY_DELETE: [debug_device_id + 3, "cancel"], 
			KEY_END: [debug_device_id + 3, "info"], 
			KEY_PAGEDOWN: [debug_device_id + 3, "select"], 
		}

		for key in debug_key_mappings:
			var remapped_device = debug_key_mappings[key][0]
			var action_suffix = debug_key_mappings[key][1]
			for prefix in ["ui", "move"]:
				var action_name = prefix + "_" + action_suffix
				if not InputMap.has_action(action_name):
					continue
				var device: = 0
				var new_event = InputEventKey.new()
				new_event.device = device
				new_event.physical_scancode = key
				
				InputMap.action_add_event(action_name, new_event)
				add_key_action(action_name, remapped_device, device, new_event)


# 复制键盘事件的逻辑键码和物理键码，并添加到指定逻辑设备的动作。
func add_key_action(action_name: String, remapped_device: int, device: int, event: InputEventKey) -> void :
	var new_event = InputEventKey.new()
	new_event.device = device
	new_event.scancode = event.scancode
	new_event.physical_scancode = event.physical_scancode
	add_action(action_name, remapped_device, 0.5, new_event)


# 按逻辑设备 ID 创建动作（如 ui_up_6），再把输入事件追加进去。
func add_action(action_name: String, remapped_device: int, deadzone: float, new_event: InputEvent) -> void :
	var new_action_name = action_name + "_" + str(remapped_device)
	if not InputMap.has_action(new_action_name):
		InputMap.add_action(new_action_name, deadzone)
	InputMap.action_add_event(new_action_name, new_event)


# 编辑器环境下将错误报告快捷键改为物理 F7，替换该动作原有事件。
func _set_bug_report_key() -> void :
	
	
	if OS.has_feature("editor"):
		InputMap.action_erase_events("open_bug_report")
		var new_key_event = InputEventKey.new()
		new_key_event.physical_scancode = KEY_F7
		InputMap.action_add_event("open_bug_report", new_key_event)
