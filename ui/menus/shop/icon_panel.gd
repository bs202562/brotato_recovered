extends Panel
class_name IconPanel


@onready var _coop_count: Label = $"%CoopCount"
@onready var _count: Label = $"%Count"
@onready var _curse: TextureRect = $"%Curse"


func _ready() -> void :
	_coop_count.visible = RunData.is_coop_run
	_count.visible = not RunData.is_coop_run
	_curse.visible = false


func set_count(count: int) -> void :
	if count <= 1:
		_coop_count.text = ""
		_count.text = ""
	else:
		_coop_count.text = "x" + str(count)
		_count.text = "x" + str(count)


func _update_stylebox(is_cursed: bool = false, tier: int = 0) -> void :
	var stylebox = get_theme_stylebox("panel").duplicate()
	_curse.visible = is_cursed
	ItemService.change_panel_stylebox_from_tier(stylebox, tier)
	
	if stylebox is StyleBoxFlat:
		stylebox.bg_color = lerp(stylebox.bg_color, Color("#c8c8c850"), 0.5)
	add_theme_stylebox_override("panel", stylebox)


func _replace_with_positive_color():
	get_node("Icon").material = UIService.replace_color_positive
