class_name TagPanel
extends PanelContainer

var _plain_text: = ""

@onready var _margin_container = $MarginContainer
@onready var _tag_effects = $MarginContainer / VBoxContainer / TagEffects
@onready var _tag_name = $MarginContainer / VBoxContainer / TagName

var small_font = preload("res://resources/fonts/actual/base/font_very_smallest_text.tres")
var normal_font = preload("res://resources/fonts/actual/base/font_smallest_text.tres")


func set_data(tag: String) -> bool:
	match tag:
		"pet":
			_tag_name.text = tr("PET")
			_tag_effects.text = tr("TAG_DESCRIPTION_PET")
		"structure":
			_tag_name.text = tr("STRUCTURE")
			_tag_effects.text = tr("TAG_DESCRIPTION_STRUCTURE")
		_:
			return false

	if RunData.is_coop_run:
		if _tag_effects.text.length() >= 300:
			_tag_effects.add_theme_font_override("normal_font", small_font)
			_tag_effects.add_theme_font_size_override("normal_font_size", 17)
		else:
			_tag_effects.add_theme_font_override("normal_font", normal_font)
			_tag_effects.add_theme_font_size_override("normal_font_size", 21)

	show()
	return true
