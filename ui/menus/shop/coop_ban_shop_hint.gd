class_name CoopBanShopHint
extends CoopShopHint

func set_text(new_text: String) -> void :
	text = new_text
	var split = Text.text(text, ["{0}", str(RunData.players_data[player_index].remaining_ban_token)]).split("{0}")
	_label1.text = split[0].strip_edges()
	_label2.text = split[1].strip_edges()

	if _label1.get_total_character_count() + _label2.get_total_character_count() >= 30:
		custom_minimum_size.x = 350
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		_label1.add_theme_font_override("font", small_font)
		_label2.add_theme_font_override("font", small_font)
	else:
		custom_minimum_size.x = 0
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_label1.add_theme_font_override("font", normal_font)
		_label2.add_theme_font_override("font", normal_font)

func update_text() -> void :
	set_text(text)
