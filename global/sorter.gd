class_name Sorter
extends Node


static func sort_depth_ascending(a: ItemAppearanceData, b: ItemAppearanceData):
	if a.depth < b.depth:
		return true
	return false

static func sort_item_by_tier(a: ItemParentData, b: ItemParentData) -> bool:
	return a.tier < b.tier
