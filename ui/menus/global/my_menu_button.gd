class_name MyMenuButton
extends MyMenuButtonParent


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用
	var _error_focus = connect("focus_entered", Callable(self, "on_focus_entered"))
	var _error_unfocus = connect("focus_exited", Callable(self, "on_focus_exited"))
	var _error_press = connect("pressed", Callable(self, "on_pressed"))
	var _error_mouse = connect("mouse_entered", Callable(self, "on_mouse_entered"))
