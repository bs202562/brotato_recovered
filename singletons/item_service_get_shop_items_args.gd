class_name ItemServiceGetShopItemsArgs
extends RefCounted

var count: int
var prev_items: = []
var locked_items: = []
var player_index: = 0
var increase_tier: = 0


# 4.x 移植: 3.x 的 setget 不拦截类内赋值，4.x 会拦截，导致 _init 里的赋值被
# readonly 保护吞掉、列表永远为空。改用私有后备变量存储真实值。
var _owned_and_shop_items_value: = []
var owned_and_shop_items: = []: get = _get_owned_and_shop_items, set = _set_owned_and_shop_items
func _get_owned_and_shop_items() -> Array:
	return _owned_and_shop_items_value
func _set_owned_and_shop_items(_v: Array) -> void :
	printerr("owned_and_shop_items is readonly")

func _init(shop_items_by_player: Array, p_player_index: int):
	player_index = p_player_index

	count = ItemService.NB_SHOP_ITEMS
	_owned_and_shop_items_value = RunData.get_player_items(p_player_index)
	for shop_item in shop_items_by_player[p_player_index]:
		if shop_item[0] is ItemData:
			_owned_and_shop_items_value.push_back(shop_item[0])
