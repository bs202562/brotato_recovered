class_name FloatingText
extends Label

signal available

@onready var _icon: Sprite2D = $"%Icon"
var _tween: Tween # 4.x 移植: Tween 节点改为 create_tween()
var has_theme_icon: = false
var player_index: = - 1


func display(content: String, direction: Vector2, duration: float, spread: float, color: Color = Color.WHITE, all_caps: bool = false) -> void :
	show()
	self_modulate = color
	text = content.to_upper() if all_caps else content # 4.x 移植: Label.uppercase 属性已移除
	var movement: = direction.rotated(randf_range( - spread / 2, spread / 2))
	pivot_offset = size / 2
	scale = Vector2.ONE
	modulate.a = 1.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(
		self,
		"position",
		position + movement,
		duration
	).from(position).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await _tween.finished

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(
		self,
		"scale",
		Vector2.ZERO,
		duration
	).from(scale).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_IN_OUT)

	_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		duration
	).from(modulate.a).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished

	hide()
	_icon.hide()
	emit_signal("available", self)


func set_icon(icon: Texture2D, icon_scale: Vector2, positive_color: bool = false) -> void :
	_icon.show()
	_icon.texture = icon
	_icon.scale = icon_scale
	_icon.position.x = get_minimum_size().x + 8
	if positive_color: replace_color_icon_with_positive_color()
	has_theme_icon = true


func replace_color_icon_with_positive_color() -> void :
	_icon.material = UIService.replace_color_positive
