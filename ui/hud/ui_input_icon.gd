extends TextureRect
class_name InputIcon

@export var input_string: String = "" # (String, "ui_info", "ui_pause", "ui_select", "ui_coop_ban", "rtrigger", "ltrigger")
@export var player_index: int = 0


func _ready():
	UIService.connect("change_device", Callable(self, "_change_controller"))
	_change_controller()


func _change_controller():
	texture = CoopService.get_player_key_texture(input_string, player_index)
