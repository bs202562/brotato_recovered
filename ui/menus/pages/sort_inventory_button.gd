extends OptionButton
class_name SortInventoryButton

enum SortingType{
	BYTIERS, 
	BYNAME, 
	HOWMANYOBTAINED, 
	HOWMANYKILLED, 
	BYSTRENGHT, 
	BYHP, 
	BYCATEGORY, 
	BYTIMEADDITIONTOINVENTORY, 
	BYWEAPONDAMAGE, 
	BYWEAPONRELOADTIME, 
	BYWEAPONRANGE, 
	BYENTITYTYPE
}

enum SavePresset{
	NONE, 
	PLAYER0_ITEM, 
	PLAYER1_ITEM, 
	PLAYER2_ITEM, 
	PLAYER3_ITEM, 
	PLAYER0_WEAPON, 
	PLAYER1_WEAPON, 
	PLAYER2_WEAPON, 
	PLAYER3_WEAPON, 
	CODEXITEM, 
	CODEXWEAPON, 
	CODEXENTITY
}

@export var inventory_to_sort_path: NodePath
@export var reverse_order_button_path: NodePath

var inventory_to_sort
var reverse_order_button: Button

var reverse_order: bool = false
var change_order: bool = false

@export var by_default: SortingType
@export var save_presset: SavePresset

@export var sort_by_tier: bool = false
@export var sort_by_name: bool = false
@export var sort_by_time_got_it: bool = false
@export var sort_by_killed_time: bool = false
@export var sort_by_strenght: bool = false
@export var sort_by_hp: bool = false
@export var sort_by_category: bool = false
@export var sort_by_when_got_it: bool = false
@export var sort_by_weapon_damage: bool = false
@export var sort_by_weapon_reload_time: bool = false
@export var sort_by_weapon_range: bool = false
@export var sort_by_type_of_entity: bool = false


func _ready():

	connect("item_selected", Callable(self, "_sort_inventory_button"))

	if not inventory_to_sort_path.is_empty():
		inventory_to_sort = get_node(inventory_to_sort_path)

		if is_instance_valid(inventory_to_sort):
			inventory_to_sort.connect("need_to_sort_inventory", Callable(self, "_sort_inventory"))

	if not reverse_order_button_path.is_empty():
		reverse_order_button = get_node(reverse_order_button_path)

		if is_instance_valid(reverse_order_button):
			reverse_order_button.connect("toggled", Callable(self, "_reverse_order_button_toggled"))

	clear()

	if sort_by_tier:
		add_item(Text.text("SORT_BY_TIER") + " ", SortingType.BYTIERS)

	if sort_by_name:
		add_item(Text.text("SORT_BY_NAME") + " ", SortingType.BYNAME)

	if sort_by_time_got_it:
		add_item(Text.text("SORT_BY_TIME_GOT_IT") + " ", SortingType.HOWMANYOBTAINED)

	if sort_by_killed_time:
		add_item(Text.text("SORT_BY_KILLED") + " ", SortingType.HOWMANYKILLED)

	if sort_by_strenght:
		add_item(Text.text("SORT_BY_STRENGHT_WAVE_20") + " ", SortingType.BYSTRENGHT)

	if sort_by_hp:
		add_item(Text.text("SORT_BY_HP_WAVE_20") + " ", SortingType.BYHP)

	if sort_by_category:
		add_item(Text.text("SORT_BY_CATEGORY") + " ", SortingType.BYCATEGORY)

	if sort_by_when_got_it:
		add_item(Text.text("SORT_BY_WHEN_GOT_IT") + " ", SortingType.BYTIMEADDITIONTOINVENTORY)

	if sort_by_weapon_damage:
		add_item(Text.text("SORT_BY_WEAPON_DAMAGE") + " ", SortingType.BYWEAPONDAMAGE)

	if sort_by_weapon_reload_time:
		add_item(Text.text("SORT_BY_WEAPON_RELOAD_TIME") + " ", SortingType.BYWEAPONRELOADTIME)

	if sort_by_weapon_range:
		add_item(Text.text("SORT_BY_WEAPON_RANGE") + " ", SortingType.BYWEAPONRANGE)

	if sort_by_type_of_entity:
		add_item(Text.text("SORT_BY_ENTITY_TYPE") + " ", SortingType.BYENTITYTYPE)

	await get_tree().process_frame

	_apply_saved_sort()

	if not is_connected("visibility_changed", Callable(self, "_apply_saved_sort")):
		connect("visibility_changed", Callable(self, "_apply_saved_sort"))


func _apply_saved_sort():

	while ProgressData.settings.sort_inventory_presset.size() < SavePresset.size():
		ProgressData.settings.sort_inventory_presset.append(null)

	while ProgressData.settings.sort_inventory_presset_reverse.size() < SavePresset.size():
		ProgressData.settings.sort_inventory_presset_reverse.append(false)

	if save_presset != SavePresset.NONE:

		var saved_sort_id = ProgressData.settings.sort_inventory_presset[save_presset]

		if saved_sort_id != null:

			var item_index = get_item_index(saved_sort_id)

			if item_index != - 1:
				select(item_index)
			else:
				select(get_item_index(by_default))

		else:
			select(get_item_index(by_default))

	else:
		select(get_item_index(by_default))

	await get_tree().process_frame

	if save_presset != SavePresset.NONE:
		var reverse_button_saved = ProgressData.settings.sort_inventory_presset_reverse[save_presset]
		if (reverse_button_saved == null):
			reverse_order_button.button_pressed = false
		else:
			reverse_order_button.button_pressed = reverse_button_saved
	else:
		reverse_order_button.button_pressed = false


func _sort_inventory_button(index: int = - 10, _inventory: Inventory = null):

	if save_presset != SavePresset.NONE:

		var item_id = get_item_id(index)

		ProgressData.settings.sort_inventory_presset[save_presset] = item_id

		ProgressData.save_settings()

	_sort_inventory(index, _inventory)


func _sort_inventory(index: int = - 10, _inventory: Inventory = null):

	var elements: Array = inventory_to_sort.get_children()

	if index == - 10:
		index = selected

	var sort_type = get_item_id(index)

	var sortingType: String
	var other_type_of_sorting: bool = false

	match sort_type:

		SortingType.BYNAME:
			sortingType = "sort_by_name"

		SortingType.BYTIERS:
			sortingType = "sort_by_tier"

		SortingType.HOWMANYOBTAINED:
			sortingType = "sort_by_time_got_it"

		SortingType.HOWMANYKILLED:
			sortingType = "sort_by_killed"

		SortingType.BYSTRENGHT:
			sortingType = "sort_by_strenght"

		SortingType.BYHP:
			sortingType = "sort_by_hp"

		SortingType.BYCATEGORY:
			sortingType = "sort_by_category"

		SortingType.BYTIMEADDITIONTOINVENTORY:
			other_type_of_sorting = true
			elements = inventory_to_sort.order_of_addition.duplicate()

		SortingType.BYWEAPONDAMAGE:
			sortingType = "sort_by_damage"

		SortingType.BYWEAPONRELOADTIME:
			sortingType = "sort_by_reload_time"

		SortingType.BYWEAPONRANGE:
			sortingType = "sort_by_range"

		SortingType.BYENTITYTYPE:
			sortingType = "sort_by_entity_type"

	if not other_type_of_sorting:
		elements.sort_custom(Callable(SortInventory, sortingType))

	if reverse_order:
		elements.reverse()

	for slot in inventory_to_sort.get_children():
		inventory_to_sort.remove_child(slot)

	for slot in elements:

		if not is_instance_valid(slot):
			continue

		inventory_to_sort.add_child(slot)

	inventory_to_sort.__set_focus_neighbours()


func _reverse_order_button_toggled(button_pressed: bool):

	reverse_order = button_pressed

	if save_presset != SavePresset.NONE:

		while ProgressData.settings.sort_inventory_presset_reverse.size() < SavePresset.size():
			ProgressData.settings.sort_inventory_presset_reverse.append(false)

		ProgressData.settings.sort_inventory_presset_reverse[save_presset] = button_pressed

		ProgressData.save_settings()

	_sort_inventory_button(selected, inventory_to_sort)


class SortInventory:

	static func sort_by_name(a, b):
		if compare_loca_names(a.item.name, b.item.name):
			return true
		return false
	static func compare_loca_names(name_a, name_b):
		return TranslationServer.translate(name_a) < TranslationServer.translate(name_b)

	static func sort_by_tier(a, b):
		if a.item.tier < b.item.tier:
			return true
		elif a.item.tier == b.item.tier:
			if a.item.name < b.item.name:
				return true
		return false

	static func sort_by_time_got_it(a, b):
		var a_quantity = a.item._get_bought_times()
		var b_quantity = b.item._get_bought_times()

		if a_quantity > b_quantity:
			return true
		elif a_quantity == b_quantity:
			if a.item.tier < b.item.tier:
				return true
			elif a.item.tier == b.item.tier:
				if a.item.name < b.item.name:
					return true

		return false

	static func sort_by_killed(a, b):
		var a_quantity = a.item._get_how_many_killed()
		var b_quantity = b.item._get_how_many_killed()

		if a_quantity > b_quantity:
			return true
		elif a_quantity == b_quantity:
			if a.item.tier < b.item.tier:
				return true
			elif a.item.tier == b.item.tier:
				if a.item.name < b.item.name:
					return true

		return false

	static func sort_by_strenght(a, b):

		if a.item.stats is Stats and b.item.stats is Stats:

			var damage_a = a.item.stats.damage + (a.item.stats.damage_increase_each_wave * 20) if a.item.stats != null else 0
			var damage_b = b.item.stats.damage + (b.item.stats.damage_increase_each_wave * 20) if b.item.stats != null else 0

			if damage_a < damage_b:
				return true
			elif damage_a == damage_b:
				if a.item.name < b.item.name:
					return true

			return false

		elif ( not (a.item.stats is Stats)) and ( not (b.item.stats is Stats)):

			if a.item.name < b.item.name:
				return true
			else:
				return false

		elif ( not (a.item.stats is Stats)) and (b.item.stats is Stats):
			return true

		elif (a.item.stats is Stats) and ( not (b.item.stats is Stats)):
			return false

	static func sort_by_hp(a, b):

		if a.item.stats is Stats and b.item.stats is Stats:

			var hp_a = a.item.stats.health + (a.item.stats.health_increase_each_wave * 20) if a.item.stats != null else 0
			var hp_b = b.item.stats.health + (b.item.stats.health_increase_each_wave * 20) if b.item.stats != null else 0

			if hp_a < hp_b:
				return true
			elif hp_a == hp_b:
				if a.item.name < b.item.name:
					return true

			return false

		elif ( not (a.item.stats is Stats)) and ( not (b.item.stats is Stats)):

			if a.item.name < b.item.name:
				return true
			else:
				return false

		elif ( not (a.item.stats is Stats)) and (b.item.stats is Stats):
			return true

		elif (a.item.stats is Stats) and ( not (b.item.stats is Stats)):
			return false

	static func sort_by_category(a, b):

		if a.item.sets[0].name < b.item.sets[0].name:
			return true

		elif a.item.sets[0].name == b.item.sets[0].name:

			if a.item.name < b.item.name:
				return true

		return false

	static func sort_by_damage(a, b):

		if a.item.stats.damage > b.item.stats.damage:
			return true

		elif a.item.stats.damage == b.item.stats.damage:

			if a.item.name < b.item.name:
				return true

		return false

	static func sort_by_reload_time(a, b):

		if a.item.stats.cooldown < b.item.stats.cooldown:
			return true

		elif a.item.stats.cooldown == b.item.stats.cooldown:

			if a.item.name < b.item.name:
				return true

		return false

	static func sort_by_range(a, b):

		if (a.item.stats.min_range + a.item.stats.max_range) < (b.item.stats.min_range + b.item.stats.max_range):
			return true

		elif (a.item.stats.min_range + a.item.stats.max_range) == (b.item.stats.min_range + b.item.stats.max_range):

			if a.item.name < b.item.name:
				return true

		return false

	static func sort_by_entity_type(a, b):

		var item_a = a.item
		var item_b = b.item

		var rank_a = get_rank(item_a)
		var rank_b = get_rank(item_b)

		if rank_a != rank_b:
			return rank_a < rank_b

		return compare_names(item_a.name, item_b.name)

	static func get_rank(item):

		if item is ItemPet:
			return 0

		if item.is_boss:
			return 3

		if item.is_elite:
			return 2

		return 1

	static func compare_names(name_a, name_b):

		var group_a = get_group_name(name_a)
		var group_b = get_group_name(name_b)

		if group_a != group_b:
			return group_a < group_b

		if name_a.length() != name_b.length():
			return name_a.length() < name_b.length()

		return name_a < name_b

	static func get_group_name(name):

		var parts = name.split("_")

		if parts.size() >= 2:
			return parts[parts.size() - 2] + "_" + parts[parts.size() - 1]

		return name
