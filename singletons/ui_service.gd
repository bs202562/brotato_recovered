extends Node

@onready var sound_error: AudioStreamWAV = preload("res://ui/sounds/cant_buy.wav")
@onready var sound_ban: AudioStreamWAV = preload("res://ui/menus/ban_item.wav")
@onready var empty_stat: Texture2D = preload("res://items/stats/empty.png")
@onready var replace_color_positive: Material = preload("res://ui/icons/icon_replace_with_positive_color.tres")

var projectile_material = preload("res://resources/shaders/projectile_material.tres")

var _is_in_animation: Array
var current_device: = 0

signal change_device()
signal icon_effect_in_description_changed(value)

func _ready():
	if Utils.on_nintendo_nx_or_ounce:
		set_process(true)
	_on_update_color_positive()
	_on_update_color_negative()

func _process(delta):
	if Utils.on_nintendo_nx_or_ounce:
		if OS_Seaven.has_controller_style_maybe_changed():
			emit_signal("change_device")


func _input(event: InputEvent) -> void :
	var new_device = _check_input(event)
	if new_device != current_device:
		current_device = new_device
		
		emit_signal("change_device")




func _check_input(event: InputEvent) -> int:
	var new_device: int
	if event is InputEventMouse:
		
		if event is InputEventMouseMotion and event.velocity.length() < 1000: return current_device # 4.x 移植: speed 改名 velocity
		new_device = CoopService.PlayerType.KEYBOARD_AND_MOUSE
		return new_device
	
	elif event is InputEventJoypadMotion and abs(event.axis_value) < 0.1: return current_device

	new_device = event.device
	if event.device == 0:
		
		if event is InputEventJoypadMotion: new_device = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
		else:
			if event is InputEventJoypadButton:
				new_device = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
			elif event is InputEventKey:
				new_device = CoopService.PlayerType.KEYBOARD_AND_MOUSE
				return new_device

	var unmapped_device = 0 if new_device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID or new_device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID else new_device
	var joy_name = Input.get_joy_name(unmapped_device)
	var joy_name_components = joy_name.to_lower().split(" ")
	if new_device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID:
		new_device = CoopService.PlayerType.KEYBOARD_AND_MOUSE
	elif Utils.on_playstation or "ps4" in joy_name_components or "ps5" in joy_name_components or "playstation" in joy_name_components or "dualsense" in joy_name_components:
		new_device = CoopService.PlayerType.GAMEPAD_PLAYSTATION
	elif Utils.on_nintendo_nx_or_ounce or "nintendo" in joy_name_components or "switch" in joy_name_components:
		new_device = CoopService.PlayerType.GAMEPAD_SWITCH
	else:
		new_device = CoopService.PlayerType.GAMEPAD_XBOX

	return new_device


func _reached_max_shake(control: Control, duration: int = 5) -> void :
	if _is_in_animation.has(control):
		return
	_is_in_animation.append(control)

	var original_scale: = control.scale
	var original_rotation: = control.rotation
	var original_modulate: = control.modulate
	var original_pivot: = control.pivot_offset

	SoundManager.play(sound_error, 0, 0.1)

	control.pivot_offset = control.size / 2
	control.scale = original_scale * Vector2(1.1, 1.1)
	control.modulate = Color(ProgressData.settings.color_negative)
	# 4.x 移植: Tween 节点已移除，改用 create_tween()
	for i in duration:
		var _range: float = float((duration * 10) - (i * 10))
		var rand_rotation: float = randf_range( - _range, _range)
		var tween = create_tween()
		tween.tween_property(control, "rotation", original_rotation, 0.03)\
			.from(original_rotation + rand_rotation).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		await tween.finished

	control.scale = original_scale
	control.modulate = original_modulate
	control.rotation = original_rotation
	control.pivot_offset = original_pivot

	_is_in_animation.erase(control)


func _entrance_animation(control: Control) -> void :
	if _is_in_animation.has(control):
		return
	_is_in_animation.append(control)

	var original_scale: = control.scale
	var original_pivot: = control.pivot_offset

	control.pivot_offset = control.size / 2

	# 4.x 移植: Tween 节点已移除，改用 create_tween()
	var tween = create_tween()
	tween.tween_property(control, "scale", original_scale, 0.1)\
		.from(Vector2(0, 0)).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	control.scale = original_scale
	control.pivot_offset = original_pivot

	_is_in_animation.erase(control)


func _ban_item_control(control: Control) -> void :
	if _is_in_animation.has(control):
		return
	_is_in_animation.append(control)

	SoundManager.play(sound_ban, 0, 0.1)

	var original_scale: = control.scale
	var original_rotation: = control.rotation
	var original_modulate: = control.modulate
	var original_pivot: = control.pivot_offset

	control.pivot_offset = control.size / 2
	control.modulate = Color(ProgressData.settings.color_negative)

	# 4.x 移植: 三个并行 Tween 节点合并为一个 create_tween() 的并行动画
	var tween = create_tween().set_parallel(true)
	tween.tween_property(control, "scale", Vector2(0.5, 0.5), 0.2)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "rotation", 0.5, 0.2)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "modulate", Color(0, 0, 0, 0), 0.2)\
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	await get_tree().process_frame
	control.scale = original_scale
	control.modulate = original_modulate
	control.rotation = original_rotation
	control.pivot_offset = original_pivot

	_is_in_animation.erase(control)

	return


func _on_update_color_positive():
	replace_color_positive.set("shader_param/new_color", Color(ProgressData.settings.color_positive))


func _on_update_color_negative():
	Utils.projectile_outline_shadermat.set_shader_parameter("color_A", Color(ProgressData.settings.color_negative))
