extends Label


func add_theme_color_override(name: StringName, color: Color) -> void :
	if name == "font_color":

		return
	super.add_theme_color_override(name, color)


func add_theme_font_override(name: StringName, font: Font) -> void :
	if name == "font":

		return
	super.add_theme_font_override(name, font)


# 4.x 移植: 字号改为独立覆盖项后,同样需要屏蔽外部修改以保持计数样式固定
func add_theme_font_size_override(name: StringName, font_size: int) -> void :
	if name == "font_size":
		return
	super.add_theme_font_size_override(name, font_size)
