class_name BanButton
extends CheckButton


func _ready() -> void :
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash):
		self.visible = false
		RunData.is_ban_mode_active = false
		return

	var _e = connect("toggled", Callable(self, "_on_toggled"))
	button_pressed = ProgressData.settings.ban_mode_toggled
	RunData.is_ban_mode_active = ProgressData.settings.ban_mode_toggled


func _on_toggled(button_pressed: bool) -> void :
	RunData.is_ban_mode_active = button_pressed
	ProgressData.settings.ban_mode_toggled = button_pressed

