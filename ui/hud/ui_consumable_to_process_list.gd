class_name UIConsumableToProcessList
extends UIItemList


func add_element(item_data: ItemParentData) -> void :
	
	var similar_icons: = _get_all_similar_elements(item_data.icon)
	var count = similar_icons.size() + 1
	if count > UIItemList.MAX_SIMILAR_ICONS:
		if count == UIItemList.MAX_SIMILAR_ICONS + 1:
			for element in similar_icons:
				element.hide()
		else:
			similar_icons[count - 2].hide()
	
	var node = element_scene.instance()
	node.set_item_data(item_data)
	node.set_count(count)
	_elements.push_back(item_data)
	_add_ui_node(node)


func remove_element(item_data: ItemParentData) -> void :
	var similar_icons: = _get_all_similar_elements(item_data.icon)
	var count = similar_icons.size() - 1
	if count >= UIItemList.MAX_SIMILAR_ICONS:
		if count == UIItemList.MAX_SIMILAR_ICONS:
			for element in similar_icons:
				element.show()
				element.set_count(count)
		else:
			similar_icons[count].set_count(count)
	
	_elements.erase(item_data)
	var elements_nodes = get_children()
	for node in elements_nodes:
		if node.item_data == item_data:
			_remove_ui_node(node)
			break


func _get_info_text() -> String:
	return "INFO_ITEM_BOX"
