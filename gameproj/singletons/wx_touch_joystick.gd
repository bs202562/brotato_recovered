extends CanvasLayer

# 手机端虚拟摇杆（自动加载单例 WxTouchJoystick）
#
# 背景：Brotato 是桌面游戏，移动只绑了键盘(button_move_*)和手柄摇杆(analog_move_*)，
# 触摸屏上没有任何移动方式。这里补一个左下角浮动摇杆，把触摸拖拽喂给 analog_move_* 动作。
#
# 为什么喂 analog 而不是 button：player_movement_behavior.gd 里 analog 和 button 取长度更大的
# 那个，analog 是连续量，能做到 360° 任意方向；button 是四个离散键，只能八向。
#
# 关于强度：unit.gd 的 get_move_input() 是 _current_movement.normalized() * speed，
# 只取方向不取大小，所以摇杆一律输出【单位向量】即可——既拿到全向控制，又天然越过
# analog_move_* 那 0.5 的 deadzone（Input.get_vector 对合成向量的长度判 deadzone）。
#
# 显隐策略：不做平台探测（wx 禁 eval，从 GDScript 问不到宿主）。改为行为自适应——
# 收到第一个触摸事件就显示，收到键盘事件就隐藏。PC 端插键盘玩自动不出现，手机端自动出现。
#
# 与 UI 的关系：摇杆【不吞事件】(不调用 set_input_as_handled)，触摸照常传给按钮，
# 所以商店/菜单点击不受影响；同时只有场上存在可操控玩家时才真正喂输入。

const ACT_LEFT := "analog_move_left"
const ACT_RIGHT := "analog_move_right"
const ACT_UP := "analog_move_up"
const ACT_DOWN := "analog_move_down"

const RADIUS := 150.0        # 摇杆最大拖拽半径（1920x1080 基准坐标系下）
const KNOB_RADIUS := 62.0
const DEAD_ZONE := 0.18      # 自身死区，低于此不产生移动
const ACTIVE_W := 0.5        # 可唤出摇杆的区域：左半屏
const ACTIVE_H := 0.45       # 下 45% 高度（避开顶部 HUD）

var _touch_id := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _vec := Vector2.ZERO
var _players := 0            # 场上可操控玩家数，由 PlayerMovementBehavior 进出场树时登记
var _touch_mode := false     # 见上：收到触摸才显示，收到键盘就隐藏
var _painter: Control


class Painter:
	extends Control

	var host = null

	func _draw() -> void:
		if host == null or not host.is_pressing():
			return
		var o: Vector2 = host.get_origin()
		var k: Vector2 = host.get_knob()
		draw_circle(o, host.RADIUS, Color(1, 1, 1, 0.10))
		# 外圈：用细线画一圈，Godot 3 的 draw_arc 需要分段
		var pts := PoolVector2Array()
		for i in range(33):
			var a := TAU * i / 32.0
			pts.append(o + Vector2(cos(a), sin(a)) * host.RADIUS)
		draw_polyline(pts, Color(1, 1, 1, 0.28), 3.0, true)
		draw_circle(k, host.KNOB_RADIUS, Color(1, 1, 1, 0.38))


func _init() -> void:
	layer = 128  # 盖在所有游戏内容之上


func _ready() -> void:
	pause_mode = PAUSE_MODE_PROCESS
	_painter = Painter.new()
	_painter.host = self
	_painter.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 绝不拦截 UI 点击
	_painter.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	add_child(_painter)
	visible = false


# ---------- 供 PlayerMovementBehavior 登记 ----------

func register_player() -> void:
	_players += 1
	_refresh_visibility()


func unregister_player() -> void:
	_players = max(0, _players - 1)
	if _players == 0:
		_release()
	_refresh_visibility()


# ---------- 供 Painter 读取 ----------

func is_pressing() -> bool:
	return _touch_id != -1


func get_origin() -> Vector2:
	return _origin


func get_knob() -> Vector2:
	return _knob


# ---------- 输入 ----------

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if _touch_mode:
			_touch_mode = false
			_release()
			_refresh_visibility()
		return

	if event is InputEventScreenTouch:
		if not _touch_mode:
			_touch_mode = true
			_refresh_visibility()
		if event.pressed:
			if _touch_id == -1 and _in_active_area(event.position):
				_touch_id = event.index
				_origin = event.position
				_knob = event.position
				_vec = Vector2.ZERO
				_painter.update()
		elif event.index == _touch_id:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var offset: Vector2 = event.position - _origin
		if offset.length() > RADIUS:
			offset = offset.normalized() * RADIUS
		_knob = _origin + offset
		var mag: float = offset.length() / RADIUS
		# 只取方向：超过死区就按单位向量输出（见文件头说明）
		_vec = Vector2.ZERO if mag < DEAD_ZONE else offset.normalized()
		_apply()
		_painter.update()


func _in_active_area(pos: Vector2) -> bool:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return pos.x <= size.x * ACTIVE_W and pos.y >= size.y * (1.0 - ACTIVE_H)


func _release() -> void:
	_touch_id = -1
	_vec = Vector2.ZERO
	_apply()
	if _painter != null:
		_painter.update()


func _apply() -> void:
	# 玩家不在场（菜单/商店）时不喂输入，避免影响 UI 或残留按下状态
	var v: Vector2 = _vec if _players > 0 else Vector2.ZERO
	_press(ACT_LEFT, max(0.0, -v.x))
	_press(ACT_RIGHT, max(0.0, v.x))
	_press(ACT_UP, max(0.0, -v.y))
	_press(ACT_DOWN, max(0.0, v.y))


func _press(action: String, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	if strength > 0.001:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _refresh_visibility() -> void:
	visible = _touch_mode and _players > 0
