class_name UIUpgradeToProcessList
extends UIItemList


func add_element(icon: Resource, level: int) -> void :
	
	var similar_icons: = _get_all_similar_elements(icon)
	var count = similar_icons.size() + 1
	if count > UIItemList.MAX_SIMILAR_ICONS:
		if count == UIItemList.MAX_SIMILAR_ICONS + 1:
			for element in similar_icons:
				element.hide()
		else:
			similar_icons[count - 2].hide()

	var node = element_scene.instance()
	node.set_data(icon, level, true)
	node.set_count(count)
	_elements.push_back(level)
	_add_ui_node(node)


func remove_element(level: int) -> void :
	var count = get_children().size() - 1
	if count >= UIItemList.MAX_SIMILAR_ICONS:
		if count == UIItemList.MAX_SIMILAR_ICONS:
			for element in get_children():
				element.show()
				element.set_count(count)
		else:
			get_child(count).set_count(count)

	_elements.erase(level)
	var elements_nodes = get_children()
	for node in elements_nodes:
		if node.level == level:
			_remove_ui_node(node)
			break


func _get_info_text() -> String:
	return "INFO_LEVEL_UP"
