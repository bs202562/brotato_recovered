class_name TakeDamageArgs
extends RefCounted

# 4.x 移植: 3.x 的 setget 不拦截类内赋值，4.x 会拦截，导致 _init 里的赋值被
# readonly 保护吞掉、字段永远是默认值。改用私有后备变量存储真实值。
var _from_player_index_value: int = 0
var from_player_index: int: get = _get_from_player_index, set = _set_from_player_index
func _get_from_player_index() -> int:
	return _from_player_index_value
func _set_from_player_index(_v: int) -> void :
	printerr("from_player_index is readonly")

var _hitbox_value: Hitbox = null
var hitbox: Hitbox: get = _get_hitbox, set = _set_hitbox
func _get_hitbox() -> Hitbox:
	return _hitbox_value
func _set_hitbox(_v: Hitbox) -> void :
	printerr("hitbox is readonly")

var from = null
var dodgeable: bool = true
var armor_applied: bool = true
var custom_sound: Resource = null
var base_effect_scale: float = 1.0
var bypass_invincibility: bool = false
var is_burning: bool = false


func _init(_from_player_index: int, _hitbox: Hitbox = null) -> void :
	_from_player_index_value = _from_player_index
	_hitbox_value = _hitbox


func get_effect_scale() -> float:
	return hitbox.effect_scale if hitbox else base_effect_scale
