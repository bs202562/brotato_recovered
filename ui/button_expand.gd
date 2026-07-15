extends MyMenuButton
class_name ExpandButton

export (NodePath) var group_visible
export var icon_up: Texture
export var icon_down: Texture

onready var bot_focus = focus_neighbour_bottom
onready var next_focus = focus_next


func _ready():
	toggle_mode = true
	connect("toggled", self, "_on_button_expand_toggled")


func _on_button_expand_toggled(button_pressed):
	get_node(group_visible).visible = button_pressed
	if button_pressed:
		icon = icon_up
		focus_neighbour_bottom = ""
		focus_next = ""
	else:
		icon = icon_down
		focus_neighbour_bottom = bot_focus
		focus_next = next_focus
