class_name FloatingTextManagerShop
extends FloatingTextManagerBase

@export var caught_sound: Resource


func stat_added(stat: int, value: int, db_mod: float, position: Vector2, pos_sounds: Array = stat_pos_sounds, neg_sounds: Array = stat_neg_sounds, positive_color: bool = false) -> void :
	display_icon(value, ItemService.get_stat_icon(stat), pos_sounds, neg_sounds, position, direction, db_mod, positive_color)


func display_shop_icon(icon: Resource, pos: Vector2, p_direction: Vector2, positive_color: bool = false) -> void :
	display("", pos, Color.WHITE, icon, duration * 2, true, p_direction, false, Vector2.ONE, positive_color)
	SoundManager.play(caught_sound, - 2, 0.2, true)
