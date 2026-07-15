extends Container
class_name EffectLine

@onready var effect_icon: TextureRect = $"%effect_icon"
@onready var text_descr: RichTextLabel = $"%text_descr"

@export var icon_locked: Texture2D

var effect: Effect
var icon_visible: bool = true

func _ready():
	UIService.connect("icon_effect_in_description_changed", Callable(self, "UI_change_icons_visibility"))


func UI_change_icons_visibility(value) -> void :
	if value:
		effect_icon.visible = icon_visible
	else:
		effect_icon.visible = false


func _display_effect(player_index: int, _effect: Effect, colored: bool = true, activate_tab: bool = true):
	effect = _effect

	var txt: = effect.get_text(player_index, colored)
	if txt == "" or txt == "[EMPTY]":
		queue_free()
		return
	text_descr.text = txt
	effect_icon.texture = effect.get_icon(player_index)
	effect_icon.custom_minimum_size = Vector2(18 * ProgressData.settings.font_size, 18 * ProgressData.settings.font_size)
	if effect_icon.texture == null and not activate_tab:
		icon_visible = false
	if ( not icon_visible) or ( not ProgressData.settings.effects_icons_in_description):
		effect_icon.hide()


func _display_special_text(text: String, icon: Texture2D = null, locked_item: bool = false):
	if locked_item:
		icon = icon_locked
	text_descr.text = text
	effect_icon.texture = icon
	effect_icon.custom_minimum_size = Vector2(18 * ProgressData.settings.font_size, 18 * ProgressData.settings.font_size)
	if icon == null:
		effect_icon.hide()
