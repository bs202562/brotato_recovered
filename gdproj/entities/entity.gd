# 实体基础层：Entity（RigidBody2D）→ Unit → Enemy / Player 等。
# 负责边界、出生/死亡、对象池回收，以及强化描边和调色。
# 生命周期：init / respawn → die → death_animation_finished → free_entity。
# free_entity 是回收复用，不是释放节点内存。
class_name Entity
extends RigidBody2D

signal died(entity, die_args)
signal stats_boosted(entity)

export (bool) var can_be_boosted: = false
export (ShaderMaterial) var outline_material
export (bool) var get_entity_spawner_ref_on_spawn: = false

var entity_spawner
# 本轮生成时连接事件的节点，回收前用它断开连接。
var entity_signal_node: Node = null
# dead 表示已进入死亡流程；_pending_die 防止延迟 die() 执行前重复受伤。
var dead: = false
var _pending_die: = false
var cleaning_up: = false
var is_boosted: = false
var _outline_colors: Array = []
var _modulation_colors: Array = []
var _boosted_args: BoostArgs
var _current_material_alpha = 1.0
var _current_material_desaturation = 0.0

var _min_pos: Vector2
var _max_pos: Vector2

onready var sprite: = $Animation / Sprite as Sprite
onready var _animation_player: = $AnimationPlayer as AnimationPlayer
onready var _animation: = $Animation as Node2D
onready var _collision: = $Collision as CollisionShape2D

var pool_id: int = Keys.empty_hash


# 按精灵贴图半尺寸收缩活动边界，为实体自身大小留出空间。
func init(zone_min_pos: Vector2, zone_max_pos: Vector2, _p_players_ref: Array = [], _entity_spawner_ref = null) -> void :

	_min_pos = Vector2(
		zone_min_pos.x + sprite.texture.get_width() / 2.0, 
		zone_min_pos.y + sprite.texture.get_height() / 2.0
	)

	_max_pos = Vector2(
		zone_max_pos.x - sprite.texture.get_width() / 2.0, 
		zone_max_pos.y - sprite.texture.get_height() / 2.0
	)



# 对象池复用入口：恢复显示、待机动画、碰撞和存活状态。
func respawn() -> void :
	show()
	_animation_player.play("idle")
	dead = false
	_pending_die = false
	sleeping = false
	_collision.disabled = false


# 死亡事件上下文：击退、清场、击杀归属、致命伤害与燃烧等信息。
class DieArgs:
	var knockback_vector: = Vector2.ZERO
	var cleaning_up: = false
	var enemy_killed_by_player: = true
	var killed_by_player_index: = - 1
	var killing_blow_dmg_value: = 0
	var is_burning: = false
	var from
	var is_bullet_hell: = false



# 开始死亡动画并发出 died 信号；此时节点还没有回收。
# 调用方应避免重复死亡，清场标记和击杀信息通过 args 传递。
func die(args: = Utils.default_die_args) -> void :
	assert ( not dead)
	_collision.disabled = true

	cleaning_up = args.cleaning_up
	_animation_player.playback_speed = 1
	dead = true
	_animation_player.play("death")
	emit_signal("died", self, args)


# 死亡动画结束后应用 RESET 动画，断开本轮生成器的事件连接，再回收。
func death_animation_finished() -> void :
	_animation_player.play("RESET")
	_animation_player.advance(1.0)

	
	if entity_signal_node:
		disconnect("died", entity_signal_node, "_on_enemy_died")
		disconnect("wanted_to_spawn_an_enemy", entity_signal_node, "on_enemy_wanted_to_spawn_an_enemy")
		disconnect("charmed", entity_signal_node, "on_enemy_charmed")

	free_entity()


# 重置强化和材质状态、让刚体休眠，然后交回主场景的对象池。
func free_entity() -> void :
	is_boosted = false
	_outline_colors.clear()
	sprite.material = null
	_current_material_alpha = 1.0
	_current_material_desaturation = 0.0
	_boosted_args = null
	sleeping = true
	Utils.get_scene_node().add_node_to_pool(self, pool_id)

# 燃烧清理接口；Entity 无具体实现，Unit 中实现实际清理。
func stop_burning() -> void :
	pass


# 保存强化参数并按需描边，属性数值的强化由子类继续处理。
func boost(boost_args: BoostArgs) -> void :
	if can_be_boosted:
		is_boosted = true
		_boosted_args = boost_args
		if boost_args.show_outline:
			add_outline(Utils.BOOST_COLOR)


# 清除强化标记、参数以及对应描边。
func boost_ended() -> void :
	is_boosted = false
	_boosted_args = null
	remove_outline(Utils.BOOST_COLOR)


# 检查指定颜色是否已存在，避免重复添加。
func has_outline(color: Color) -> bool:
	for outline in _outline_colors:
		if outline == color:
			return true
	return false


# 追加独立的描边颜色；可用槽位受描边 shader 限制。
func add_outline(color: Color, alpha: float = 1.0, desaturation: float = 0.0) -> void :
	assert (_outline_colors.size() <= 4, "No more outlines can be supported. Adapt shader to support it")
	if _outline_colors.has(color):
		return
	_outline_colors.append(color)
	_set_outlines(alpha, desaturation)


# 移除指定描边并更新剩余颜色。
func remove_outline(color: Color) -> void :
	_outline_colors.erase(color)
	_set_outlines()


# 创建本实体独立的 ShaderMaterial，避免影响其他实例。
# 重建时保留记录的透明度和去饱和度；无描边则移除材质。
func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void :
	if not _outline_colors:
		sprite.material = null
		return

	sprite.material = ShaderMaterial.new()
	sprite.material.shader = outline_material.shader

	sprite.material.set_shader_param("texture_size", sprite.texture.get_size())

	if alpha < 1.0:
		_current_material_alpha = alpha
		sprite.material.set_shader_param("alpha", alpha)
	else:
		sprite.material.set_shader_param("alpha", _current_material_alpha)

	if desaturation > 0.0:
		_current_material_desaturation = desaturation
		sprite.material.set_shader_param("desaturation", desaturation)
	else:
		sprite.material.set_shader_param("desaturation", _current_material_desaturation)

	for i in range(_outline_colors.size()):
		sprite.material.set_shader_param("outline_color_%s" % i, _outline_colors[i])


# 追加调色状态，最后加入的颜色覆盖动画节点。
func _set_color_modulation(color: Color) -> void :
	_modulation_colors.push_back(color)
	_animation.modulate = color


# 移除一个调色状态后恢复最后剩余颜色；列表为空则恢复白色。
func remove_color_modulation(color: Color) -> void :
	_modulation_colors.erase(color)
	if _modulation_colors.size() > 0:
		_animation.modulate = _modulation_colors[_modulation_colors.size() - 1]
	else:
		_animation.modulate = Color.white
