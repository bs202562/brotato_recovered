class_name PopupBetaSaveWarning
extends PopupAnouncement

func _on_validation_button_pressed():
	_close_popup()
	ProgressData.show_main_title_beta_save_warning_popup = false
	ProgressData.save()
