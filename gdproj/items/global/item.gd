# 战场掉落物的公共基类（Area2D），Gold 和 Consumable 继承此类。
# 负责掉落散开、短暂停留、吸附移动和拾取通知；奖励结算由 picked_up 的监听者处理。
# 生命周期：reset（隐藏待用）→ drop（掉落）→ 散开/等待 → 吸附 → pickup → reset。
# 吸附目标与拾取时机由玩家、宠物等外部节点的检测区域决定。
class_name Item
extends Area2D

# 吸附起始速度；ATTRACT_ACCELERATION 是每个物理帧的速度增量，代码中未乘 delta。
const INITIAL_ATTRACT_SPEED: float = 500.0
const ATTRACT_ACCELERATION: float = 20.0

# 把掉落物实例和拾取者索引交给主场景，用于材料、消耗品效果及统计处理。
signal picked_up(item, player_index)

# 掉落后的散开阶段：先向目标点插值移动，再允许吸附追踪目标。
var push_back: = true
var push_back_destination: = Vector2(0, 0)
# 外部设置的吸附目标，可以是玩家、宠物或波次结算时的收集节点。
var attracted_by: Node2D
# 以 60 帧为基准的等待计数，按 60 * delta 递减；10 约等于 1/6 秒。
var idle_time_after_pushed_back: = 10.0

# 散开阶段的插值系数，不是固定的像素移动速度。
var _push_back_speed: = 5
var _current_speed: = INITIAL_ATTRACT_SPEED

# 由主场景管理的重复结算保护标记；reset() 不修改它，重新生成时由外部清零。
var already_picked_up: = false

onready var sprite = $Sprite as Sprite


# 节点首次就绪时先进入隐藏待用状态。
func _ready() -> void :
	reset()


# 恢复可复用的初始状态，关闭物理帧更新；不销毁节点，也不在此执行奖励结算。
func reset() -> void :
	hide()
	# monitorable 控制“能否被其他 Area2D 检测”，延迟关闭以避开物理回调中的修改。
	set_deferred("monitorable", false)
	set_physics_process(false)
	scale = Vector2(1.0, 1.0)
	push_back = true
	push_back_destination = Vector2(0, 0)
	attracted_by = null
	idle_time_after_pushed_back = 10.0
	_push_back_speed = 5
	_current_speed = INITIAL_ATTRACT_SPEED


# 从指定世界坐标掉落，设置朝向和散开终点，重新开启物理更新。
# 此函数不重置吸附/计时状态，调用前应已完成 reset 或首次 _ready 初始化。
func drop(pos: Vector2, p_rotation: float, p_push_back_destiation: Vector2) -> void :
	global_position = pos
	rotation = p_rotation
	push_back_destination = p_push_back_destiation
	show()
	set_physics_process(true)


# 替换掉落物外观，例如不同材料图案；Sprite 尚未就绪时跳过。
func set_texture(texture: Resource) -> void :
	if sprite != null:
		sprite.texture = texture


# 按优先级处理散开、等待和吸附，每帧只进入其中一个分支。
func _physics_process(delta: float) -> void :
	# 距离平方大于 400 即距离超过 20 像素；越靠近终点，插值移动越慢。
	if push_back and global_position.distance_squared_to(push_back_destination) > 400:
		global_position = global_position.linear_interpolate(push_back_destination, delta * _push_back_speed)
	elif idle_time_after_pushed_back > 0:
		# 散开接近终点后开放外部检测，但等待计数耗尽前仍不执行吸附移动。
		if not monitorable:
			monitorable = true
		push_back = false
		idle_time_after_pushed_back -= 60 * delta
	elif push_back:
		# 等待已结束、但散开标记仍存在时，先结束散开阶段。
		push_back = false
	elif attracted_by != null:
		# 有 dead 属性的目标死亡时解除吸附，恢复初始速度，等待外部重新指定目标。
		if "dead" in attracted_by and attracted_by.dead:
			attracted_by = null
			_current_speed = INITIAL_ATTRACT_SPEED
		else:
			# 朝目标当前世界坐标移动；这里只追踪位置，不直接触发 pickup。
			global_position = global_position.move_toward(attracted_by.global_position, delta * _current_speed)
			_current_speed += ATTRACT_ACCELERATION
	else:
		# 静止且无目标时停止逐帧更新；外部开始吸附时需再次 set_physics_process(true)。
		set_physics_process(false)


# 外部拾取区域调用：先通知监听者读取当前掉落物数据，再重置隐藏。
# 顺序很重要，例如 Gold.reset() 会恢复材料 value，结算必须发生在它之前。
func pickup(player_index: int) -> void :
	emit_signal("picked_up", self, player_index)
	reset()
