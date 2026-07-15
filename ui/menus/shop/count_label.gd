extends Label


func add_theme_color_override(name: StringName, color: Color) -> void :
	if name == "font_color":

		return
	super.add_theme_color_override(name, color)


func add_theme_font_override(name: StringName, font: Font) -> void :
	if name == "font":

		return
	super.add_theme_font_override(name, font)
