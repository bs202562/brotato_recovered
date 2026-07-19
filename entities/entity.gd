class_name Entity
extends RigidBody2D

signal died(entity, die_args)
signal stats_boosted(entity)

@export var can_be_boosted := false
@export var outline_material: ShaderMaterial
@export var get_entity_spawner_ref_on_spawn := false

var entity_spawner
var entity_signal_node: Node = null
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

@onready var sprite: = $Animation / Sprite2D as Sprite2D
@onready var _animation_player: = $AnimationPlayer as AnimationPlayer
@onready var _animation: = $Animation as Node2D
@onready var _collision: = $Collision as CollisionShape2D

var pool_id: int = Keys.empty_hash


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, _p_players_ref: Array = [], _entity_spawner_ref = null) -> void :

	_min_pos = Vector2(
		zone_min_pos.x + sprite.texture.get_width() / 2.0, 
		zone_min_pos.y + sprite.texture.get_height() / 2.0
	)

	_max_pos = Vector2(
		zone_max_pos.x - sprite.texture.get_width() / 2.0, 
		zone_max_pos.y - sprite.texture.get_height() / 2.0
	)



func respawn() -> void :
	show()
	_animation_player.play("idle")
	dead = false
	_pending_die = false
	sleeping = false
	_collision.disabled = false


class DieArgs:
	var knockback_vector: = Vector2.ZERO
	var cleaning_up: = false
	var enemy_killed_by_player: = true
	var killed_by_player_index: = - 1
	var killing_blow_dmg_value: = 0
	var is_burning: = false
	var from
	var is_bullet_hell: = false



func die(args = Utils.default_die_args) -> void :
	assert ( not dead)
	_collision.disabled = true

	cleaning_up = args.cleaning_up
	_animation_player.speed_scale = 1
	dead = true
	_animation_player.play("death")
	emit_signal("died", self, args)


func death_animation_finished() -> void :
	_animation_player.play("RESET")
	_animation_player.advance(1.0)

	
	if entity_signal_node:
		disconnect("died", Callable(entity_signal_node, "_on_enemy_died"))
		disconnect("wanted_to_spawn_an_enemy", Callable(entity_signal_node, "on_enemy_wanted_to_spawn_an_enemy"))
		disconnect("charmed", Callable(entity_signal_node, "on_enemy_charmed"))

	free_entity()


func free_entity() -> void :
	is_boosted = false
	_outline_colors.clear()
	sprite.material = null
	_current_material_alpha = 1.0
	_current_material_desaturation = 0.0
	_boosted_args = null
	sleeping = true
	Utils.get_scene_node().add_node_to_pool(self, pool_id)

func stop_burning() -> void :
	pass


func boost(boost_args: BoostArgs) -> void :
	if can_be_boosted:
		is_boosted = true
		_boosted_args = boost_args
		if boost_args.show_outline:
			add_outline(Utils.BOOST_COLOR)


func boost_ended() -> void :
	is_boosted = false
	_boosted_args = null
	remove_outline(Utils.BOOST_COLOR)


func has_outline(color: Color) -> bool:
	for outline in _outline_colors:
		if outline == color:
			return true
	return false


func add_outline(color: Color, alpha: float = 1.0, desaturation: float = 0.0) -> void :
	assert (_outline_colors.size() <= 4, "No more outlines can be supported. Adapt shader to support it")
	if _outline_colors.has(color):
		return
	_outline_colors.append(color)
	_set_outlines(alpha, desaturation)


func remove_outline(color: Color) -> void :
	_outline_colors.erase(color)
	_set_outlines()


func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void :
	if not _outline_colors:
		sprite.material = null
		return

	sprite.material = ShaderMaterial.new()
	sprite.material.shader = outline_material.shader

	sprite.material.set_shader_parameter("texture_size", sprite.texture.get_size())

	if alpha < 1.0:
		_current_material_alpha = alpha
		sprite.material.set_shader_parameter("alpha", alpha)
	else:
		sprite.material.set_shader_parameter("alpha", _current_material_alpha)

	if desaturation > 0.0:
		_current_material_desaturation = desaturation
		sprite.material.set_shader_parameter("desaturation", desaturation)
	else:
		sprite.material.set_shader_parameter("desaturation", _current_material_desaturation)

	for i in range(_outline_colors.size()):
		sprite.material.set_shader_parameter("outline_color_%s" % i, _outline_colors[i])


func _set_color_modulation(color: Color) -> void :
	_modulation_colors.push_back(color)
	_animation.modulate = color


func remove_color_modulation(color: Color) -> void :
	_modulation_colors.erase(color)
	if _modulation_colors.size() > 0:
		_animation.modulate = _modulation_colors[_modulation_colors.size() - 1]
	else:
		_animation.modulate = Color.WHITE
