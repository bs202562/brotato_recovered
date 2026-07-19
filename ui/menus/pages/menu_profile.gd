class_name MenuProfile
extends Control

signal back_button_pressed

@export var snd_switch_save: AudioStreamWAV
@export var snd_switch_save_display: AudioStreamWAV

@onready var profileButton_1 = $"%ProfileButton1" as Button
@onready var profileButton_2 = $"%ProfileButton2"
@onready var profileButton_3 = $"%ProfileButton3"

@onready var selectButton = $"%Select"
@onready var resetButton = $"%Reset"
@onready var unlockAllButton = $"%UnlockAll"
@onready var copyButton1 = $"%Copy1" as Button
@onready var copyButton2 = $"%Copy2" as Button
@onready var backButton = $"%Back_Button" as Button
@onready var cancelResetPopUpButton = $"%ResetCancelButton"
@onready var cancelUnlockPopUpButton = $"%UnlockCancelButton"
@onready var cancelCopyPopUpButton = $"%CopyCancelButton"

@onready var profil_name_id = $"%label_profil_id" as Label
@onready var profil_selected_icon = $"%profil_is_selected" as TextureRect
@onready var runWonCountLabel = $"%RunWonCount" as Label
@onready var charactersUnlockedCountLabel = $"%CharactersUnlockedCount" as Label
@onready var challengesUnlockedCountLabel = $"%ChallengesUnlockedCount" as Label
@onready var hasRunValueLabel = $"%HasRunValue" as Label
@onready var animationBrotato = $"%Animation_Brotato" as AnimationPlayer
@onready var copyLabel = $"%CopyLabel"

@onready var mainPanel = $"%MainPanel"
@onready var resetPopUpPanel = $"%ResetPopUpPanel"
@onready var unlockPopUpPanel = $"%UnlockAllPopUpPanel"
@onready var copyPopUpPanel = $"%CopyPopUpPanel"

@onready var profil0Selected = $"%profil_0_selected" as ColorRect
@onready var profil1Selected = $"%profil_1_selected" as ColorRect
@onready var profil2Selected = $"%profil_2_selected" as ColorRect

const margin_flop_disk: int = 110
@onready var profil0Margin = $"%margin_save1" as MarginContainer
@onready var profil1Margin = $"%margin_save2" as MarginContainer
@onready var profil2Margin = $"%margin_save3" as MarginContainer

@onready var audio_stream = $"%AudioStreamPlayer" as AudioStreamPlayer
@onready var flash = $"%Flash" as ColorRect

@onready var focus_before_created: Control = get_viewport().gui_get_focus_owner()
@onready var animation_tree: AnimationTree = $"%AnimationTree"
@onready var animation_player: AnimationPlayer = $"%AnimationPlayer"

@onready var _unlockall_icon: TextureRect = $"%unlockall_icon"

var profileButtons: Array
var actual_save_selected: int

var view_id = 0
var stats = []


var from_id: = 0
var to_id: = 0
var copyUsedButton: = false

func _input(event):
	if not self.visible:
		return

	if event.is_action_released("ui_cancel"):
		_on_BackButton_pressed()
	if event.is_action_pressed("ltrigger") and view_id > 0:
		active_profile_button(view_id - 1)
	if event.is_action_pressed("rtrigger") and view_id < 2:
		active_profile_button(view_id + 1)

func _on_BackButton_pressed() -> void :
	if ( not resetPopUpPanel.visible) and ( not unlockPopUpPanel.visible) and ( not copyPopUpPanel.visible):
		focus_before_created.grab_focus()
		emit_signal("back_button_pressed")
	else:
		if resetPopUpPanel.visible:
			resetPopUpPanel.hide()
			resetButton.grab_focus()
		elif unlockPopUpPanel.visible:
			unlockPopUpPanel.hide()
			unlockAllButton.grab_focus()
		elif copyPopUpPanel.visible:
			copyPopUpPanel.hide()
			if copyUsedButton:
				copyButton1.grab_focus()
			else:
				copyButton2.grab_focus()
		mainPanel.show()

func _ready():
	profileButtons = [profileButton_1, profileButton_2, profileButton_3]

func init():
	focus_before_created = get_viewport().gui_get_focus_owner()
	stats = ProgressData.get_profile_stats()
	active_profile_button(ProgressData.current_profile_id)
	update_view()
	animation_tree.set("parameters/conditions/finish", false)
	animation_tree.active = false
	visible = false
	selectButton.grab_focus()
	await get_tree().create_timer(0.01).timeout
	animation_tree.active = true
	visible = true
	await get_tree().create_timer(0.25).timeout
	_display_save_selected(false)

func active_profile_button(id: int) -> void :
	for i in range(3):
		profileButtons[i].set_pressed_no_signal(false)
	profileButtons[id].set_pressed_no_signal(true)
	view_id = id

	update_view()

func update_view():
	audio_stream.stream = snd_switch_save_display
	audio_stream.play()

	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "modulate", Color(1, 1, 1, 1), 0.025).from(Color(1, 1, 1, 0))
	await tween.finished

	selectButton.disabled = view_id == ProgressData.current_profile_id
	selectButton.active = not selectButton.disabled
	runWonCountLabel.text = str(stats[view_id].run_won)
	charactersUnlockedCountLabel.text = str(stats[view_id].characters_unlocked)
	challengesUnlockedCountLabel.text = str(stats[view_id].challenges_completed)
	profil_selected_icon.visible = actual_save_selected == view_id
	_unlockall_icon.visible = stats[view_id].is_unlock_all_save == 1

	var no_save: bool = stats[view_id].challenges_completed <= 0

	if view_id == 0:
		profil_name_id.text = profileButton_1.get_node("Label").text
		copyButton1.text = Text.text("PROFIL_COPY2")
		copyButton2.text = Text.text("PROFIL_COPY3")

		profil0Selected.color = Color("59b972")
		profil1Selected.color = Color("1d1d1d")
		profil2Selected.color = Color("1d1d1d")

	elif view_id == 1:
		profil_name_id.text = profileButton_2.get_node("Label").text
		copyButton1.text = Text.text("PROFIL_COPY1")
		copyButton2.text = Text.text("PROFIL_COPY3")

		profil1Selected.color = Color("59b972")
		profil0Selected.color = Color("1d1d1d")
		profil2Selected.color = Color("1d1d1d")

	elif view_id == 2:
		profil_name_id.text = profileButton_3.get_node("Label").text
		copyButton1.text = Text.text("PROFIL_COPY1")
		copyButton2.text = Text.text("PROFIL_COPY2")

		profil2Selected.color = Color("59b972")
		profil0Selected.color = Color("1d1d1d")
		profil1Selected.color = Color("1d1d1d")

	if stats[view_id].has_run_state:
		hasRunValueLabel.text = Text.text("PROFIL_INRUN_YES")
		animationBrotato.play("run_on")
	elif not no_save:
		hasRunValueLabel.text = Text.text("PROFIL_INRUN_NO")
		animationBrotato.play("run_off")
	else:
		animationBrotato.play("run_nosave")

	tween = flash.create_tween()
	tween.tween_property(flash, "modulate", Color(1, 1, 1, 0), 0.1).from(Color(1, 1, 1, 1))
	await tween.finished



func _on_Back_Button_pressed():
	animation_tree.set("parameters/conditions/finish", true)
	await get_tree().create_timer(0.32).timeout
	focus_before_created.grab_focus()
	emit_signal("back_button_pressed")


func _on_ProfileButton1_toggled(button_pressed):
	if button_pressed:
		active_profile_button(0)


func _on_ProfileButton2_toggled(button_pressed):
	if button_pressed:
		active_profile_button(1)


func _on_ProfileButton3_toggled(button_pressed):
	if button_pressed:
		active_profile_button(2)


func _on_Select_pressed():
	selectButton.disabled = true
	selectButton.active = false
	ProgressData.load_profile_save(view_id)
	_display_save_selected()


func _display_save_selected(play_sound: bool = true):
	actual_save_selected = view_id

	profil_selected_icon.visible = true

	var margin_on: MarginContainer
	var margin_off_0: MarginContainer
	var margin_off_1: MarginContainer

	if view_id == 0:
		margin_on = profil0Margin
		margin_off_0 = profil1Margin
		margin_off_1 = profil2Margin
	elif view_id == 1:
		margin_on = profil1Margin
		margin_off_0 = profil0Margin
		margin_off_1 = profil2Margin
	elif view_id == 2:
		margin_on = profil2Margin
		margin_off_0 = profil1Margin
		margin_off_1 = profil0Margin

	
	var tween_on = margin_on.create_tween().set_parallel(true)
	tween_on.tween_property(margin_on, "offset_top", margin_flop_disk, 0.1).from(margin_on.offset_top).set_trans(Tween.TRANS_SINE)
	tween_on.tween_property(margin_on, "offset_bottom", 372, 0.1).from(margin_on.offset_bottom).set_trans(Tween.TRANS_SINE)
	var tween_off_0 = margin_off_0.create_tween().set_parallel(true)
	tween_off_0.tween_property(margin_off_0, "offset_top", 0, 0.1).from(margin_off_0.offset_top).set_trans(Tween.TRANS_SINE)
	tween_off_0.tween_property(margin_off_0, "offset_bottom", 372 - margin_flop_disk, 0.1).from(margin_off_0.offset_bottom).set_trans(Tween.TRANS_SINE)
	var tween_off_1 = margin_off_1.create_tween().set_parallel(true)
	tween_off_1.tween_property(margin_off_1, "offset_top", 0, 0.1).from(margin_off_1.offset_top).set_trans(Tween.TRANS_SINE)
	tween_off_1.tween_property(margin_off_1, "offset_bottom", 372 - margin_flop_disk, 0.1).from(margin_off_1.offset_bottom).set_trans(Tween.TRANS_SINE)

	if play_sound:
		audio_stream.stream = snd_switch_save
		audio_stream.play()

	
	await get_tree().create_timer(0.1).timeout
	var save = actual_save_selected
	while actual_save_selected == save:
		var rand_offset: float = randf_range(0, 8)
		var flop_tween = margin_on.create_tween().set_parallel(true)
		flop_tween.tween_property(margin_on, "offset_top", margin_flop_disk - rand_offset, 0.05).from(margin_on.offset_top).set_trans(Tween.TRANS_SINE)
		flop_tween.tween_property(margin_on, "offset_bottom", 372 - rand_offset, 0.05).from(margin_on.offset_bottom).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(0.05).timeout



func _on_Reset_pressed():
	resetPopUpPanel.show()
	cancelResetPopUpButton.grab_focus()

func _on_ResetConfirmButton_pressed():
	ProgressData.reset_save_profile(view_id)
	stats = ProgressData.get_profile_stats()
	update_view()
	if (ProgressData.current_profile_id == view_id):
		ProgressData.load_profile_save(ProgressData.current_profile_id)
	resetPopUpPanel.hide()
	mainPanel.show()
	resetButton.grab_focus()

func _on_ResetCancelButton_pressed():
	resetPopUpPanel.hide()
	mainPanel.show()
	resetButton.grab_focus()


func _on_UnlockAll_pressed():
	unlockPopUpPanel.show()
	cancelUnlockPopUpButton.grab_focus()


func _on_UnlockConfirmButton_pressed():
	ProgressData.unlock_all_save_profile(view_id)
	stats = ProgressData.get_profile_stats()
	update_view()
	if (ProgressData.current_profile_id == view_id):
		ProgressData.load_profile_save(ProgressData.current_profile_id)
	unlockPopUpPanel.hide()
	mainPanel.show()
	unlockAllButton.grab_focus()


func _on_UnlockCancelButton_pressed():
	unlockPopUpPanel.hide()
	mainPanel.show()
	unlockAllButton.grab_focus()



func _on_Copy1_pressed():
	copyUsedButton = true

	to_id = view_id
	if view_id == 0:
		from_id = 1
	elif view_id == 1 or view_id == 2:
		from_id = 0

	copyPopUpPanel.show()
	copyLabel.text = Text.text("PROFILE_COPY_QUOTE", [str(from_id + 1), str(to_id + 1)])
	cancelCopyPopUpButton.grab_focus()


func _on_Copy2_pressed():
	copyUsedButton = false

	to_id = view_id
	if view_id == 0 or view_id == 1:
		from_id = 2
	elif view_id == 2:
		from_id = 1

	copyPopUpPanel.show()
	copyLabel.text = Text.text("PROFILE_COPY_QUOTE", [str(from_id + 1), str(to_id + 1)])
	cancelCopyPopUpButton.grab_focus()


func _on_CopyCancelButton_pressed():
	copyPopUpPanel.hide()
	mainPanel.show()
	if copyUsedButton:
		copyButton1.grab_focus()
	else:
		copyButton2.grab_focus()


func _on_CopyConfirmButton_pressed():
	ProgressData.copy_save_profile(from_id, to_id)
	if ProgressData.current_profile_id == to_id:
		ProgressData.load_profile_save(ProgressData.current_profile_id)


	stats = ProgressData.get_profile_stats()
	update_view()

	copyPopUpPanel.hide()
	mainPanel.show()
	if copyUsedButton:
		copyButton1.grab_focus()
	else:
		copyButton2.grab_focus()
