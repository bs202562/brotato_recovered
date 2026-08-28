extends HBoxContainer

const DEFAULT_TEXTURE_SIZE: int = 50

export var texture_size: = DEFAULT_TEXTURE_SIZE
export var show_keyboard: = true

onready var _label1 = $"%Label1"
onready var _label2 = $"%Label2"
onready var _label3 = $"%Label3"
onready var _texture_rect = $"%TextureRect"
onready var _texture_rect2 = $"%TextureRect2"


func _ready():
	if Utils.is_on_console():
		show_keyboard = OS_Seaven.has_keyboard()

	if Utils.on_gdk:
		_texture_rect.texture = CoopService.get_input_type_key_texture("ui_accept", CoopService.PlayerType.GAMEPAD_XBOX, 0)
	
	if Utils.on_nintendo_nx_or_ounce:
		_texture_rect.texture = CoopService.get_input_type_key_texture("ui_accept", CoopService.PlayerType.GAMEPAD_SWITCH, 4)
	
	if Utils.on_playstation:
		_texture_rect.texture = CoopService.get_input_type_key_texture("ui_accept", CoopService.PlayerType.GAMEPAD_PLAYSTATION, 0)
	
	
	add_constant_override("separation", get_constant("separation") * texture_size / DEFAULT_TEXTURE_SIZE)

	for texture_rect in [_texture_rect, _texture_rect2]:
		texture_rect.rect_min_size = Vector2(texture_size, texture_size)
	var text = tr("COOP_HOLD_TO_JOIN")
	text = text.replace("{1}", "{0}")
	var split = text.split("{0}")
	
	if split.size() < 3:
		return

	if Utils.on_gdk:
		_label1.text = split[0].strip_edges()
		_label2.text = split[1].strip_edges()
		_label3.text = split[2].strip_edges()

		if not show_keyboard:
			_label2.hide()
			_texture_rect2.hide()
		return
		
	_label1.text = split[0].strip_edges()
	_label1.visible = not _label1.text.empty()
	_label2.text = split[1].strip_edges()
	_label3.text = split[2].strip_edges()
	_label3.visible = not _label3.text.empty()

	if not show_keyboard:
		_label2.hide()
		_texture_rect2.hide()


func _process(_increment: float) -> void :
	if Utils.is_on_console():
		
		if not Utils.on_gdk:
			return

		if show_keyboard == OS_Seaven.has_keyboard():
			return

		show_keyboard = OS_Seaven.has_keyboard()

		if show_keyboard:
			_label2.show()
			_texture_rect2.show()
		else:
			_label2.hide()
			_texture_rect2.hide()

