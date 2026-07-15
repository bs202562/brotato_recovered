class_name UIItemList
extends HBoxContainer

const COOP_ELEMENT_SCALE: = 0.77
const MAX_SIMILAR_ICONS: int = 4

signal ui_element_mouse_entered(ui_element, text)
signal ui_element_mouse_exited(ui_element)

@export var element_scene: PackedScene = null

var _elements: = []


func is_empty() -> bool:
	return _elements.is_empty()


func on_ui_element_mouse_entered(ui_element: Node) -> void :
	emit_signal("ui_element_mouse_entered", ui_element, _get_info_text())


func on_ui_element_mouse_exited(ui_element: Node) -> void :
	emit_signal("ui_element_mouse_exited", ui_element)


func _add_ui_node(node: Node) -> void :
	if RunData.is_coop_run:
		node.custom_minimum_size *= COOP_ELEMENT_SCALE
	add_child(node)
	var _error_mouse_entered = node.connect("ui_element_mouse_entered", Callable(self, "on_ui_element_mouse_entered"))
	var _error_mouse_exited = node.connect("ui_element_mouse_exited", Callable(self, "on_ui_element_mouse_exited"))


func _remove_ui_node(node: Node) -> void :
	remove_child(node)
	node.queue_free()
	node.disconnect("ui_element_mouse_entered", Callable(self, "on_ui_element_mouse_entered"))
	node.disconnect("ui_element_mouse_exited", Callable(self, "on_ui_element_mouse_exited"))


func _get_all_similar_elements(icon: Texture2D) -> Array:
	var list_of_similar_nodes: = []
	for node in get_children():
		if node.texture == icon:
			list_of_similar_nodes.append(node)
	return list_of_similar_nodes


func _get_info_text() -> String:
	return ""
