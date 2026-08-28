class_name UIUpgradeToProcessElement
extends TextureRect

signal ui_element_mouse_entered(ui_element)
signal ui_element_mouse_exited(ui_element)

var level: int = 0


func set_data(icon: Resource, p_level: int, positive_color: bool = false) -> void :
	level = p_level
	texture = icon
	if positive_color: material = UIService.replace_color_positive


func set_count(count: int) -> void :
	if count > UIItemList.MAX_SIMILAR_ICONS:
		$Label.text = str(count)
	else:
		$Label.text = ""


func _on_UIUpgradeToProcessElement_mouse_entered() -> void :
	emit_signal("ui_element_mouse_entered", self)


func _on_UIUpgradeToProcessElement_mouse_exited() -> void :
	emit_signal("ui_element_mouse_exited", self)
