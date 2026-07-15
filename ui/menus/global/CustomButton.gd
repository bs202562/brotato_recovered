extends MyMenuButton
class_name Custombutton

@export var labels_np: Array = [] # (Array, NodePath)

func on_focus_entered() -> void :
	super.on_focus_entered()
	for label_np in labels_np:
		get_node(label_np).modulate = Color(0, 0, 0, 1)


func on_focus_exited() -> void :
	super.on_focus_exited()
	for label_np in labels_np:
		get_node(label_np).modulate = Color(1, 1, 1, 1)
