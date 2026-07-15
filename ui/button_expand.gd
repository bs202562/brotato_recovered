extends MyMenuButton
class_name ExpandButton

@export var group_visible: NodePath
@export var icon_up: Texture2D
@export var icon_down: Texture2D

@onready var bot_focus = focus_neighbor_bottom
@onready var next_focus = focus_next


func _ready():
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	toggle_mode = true
	connect("toggled", Callable(self, "_on_button_expand_toggled"))


func _on_button_expand_toggled(button_pressed):
	get_node(group_visible).visible = button_pressed
	if button_pressed:
		icon = icon_up
		focus_neighbor_bottom = ""
		focus_next = ""
	else:
		icon = icon_down
		focus_neighbor_bottom = bot_focus
		focus_next = next_focus
