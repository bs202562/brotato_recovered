class_name EliteContainer
extends Inventory

var elite_elements: = []
var displays_something: = false

func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	elite_elements = get_children()

	for element in elite_elements:
		element.hide()

		if element_size != Utils.BASE_INVENTORY_ELEMENT_SIZE:
			element.set_element_size(element_size)
			if element_size.x <= 80 and element_size.y <= 80:
				element.call_deferred("set_font", element_font_small)

	if RunData.elites_spawn.size() <= 0: return

	var next_wave = RunData.current_wave + 1
	var next_elite_index = 0
	while RunData.elites_spawn[next_elite_index][0] < next_wave:
		next_elite_index += 1
		if next_elite_index >= RunData.elites_spawn.size():
			break
	for i in min(RunData.elites_spawn.size(), elite_elements.size()):
		if next_elite_index + i >= RunData.elites_spawn.size(): continue
		var wave_number: int = RunData.elites_spawn[next_elite_index + i][0]
		if (( not RunData.is_endless_run) and wave_number > 20) or wave_number <= 0:
			continue
		
		
		
		if wave_number == next_wave:
			var stylebox_color = elite_elements[i].get_theme_stylebox("normal").duplicate()
			ItemService.change_inventory_element_stylebox_from_tier(stylebox_color, Tier.DANGER_0, 0.25)
			elite_elements[i].add_theme_stylebox_override("normal", stylebox_color)

		elite_elements[i].show()
		displays_something = true

		if RunData.elites_spawn[next_elite_index + i][1] == EliteType.ELITE:
			elite_elements[i].set_icon(ItemService.get_icon(Keys.icon_elite_hash))
		elif RunData.elites_spawn[next_elite_index + i][1] == EliteType.HORDE:
			elite_elements[i].set_icon(ItemService.get_icon(Keys.icon_horde_hash))

		elite_elements[i].set_number(wave_number)
