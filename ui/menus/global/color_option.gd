class_name ColorOption
extends Container

onready var button_expand: Button = $"%button_expand"
onready var setup_color: Control = $"%Setup_Color"
onready var rect_color: ColorRect = $"%Rect_color"
onready var slider_hue: Slider = $"%Slider_Hue"
onready var slider_saturation: Slider = $"%Slider_Saturation"
onready var slider_value: Slider = $"%Slider_Value"
onready var ramp_saturation: Gradient = $"%ramp_saturation".texture.gradient
onready var ramp_value: Gradient = $"%ramp_value".texture.gradient

signal color_changed(color)
signal color_reset()


func _ready():
	ramp_saturation = ramp_saturation.duplicate()
	$"%ramp_saturation".texture = $"%ramp_saturation".texture.duplicate()
	$"%ramp_saturation".texture.gradient = ramp_saturation
	ramp_value = ramp_value.duplicate()
	$"%ramp_value".texture = $"%ramp_value".texture.duplicate()
	$"%ramp_value".texture.gradient = ramp_value
	_update_slider_color(rect_color.color)

func _init_color(color: Color) -> void :
	slider_hue.value = color.h
	slider_saturation.value = color.s
	slider_value.value = color.v
	_update_slider_color(color)


func _on_HSlider_hue_changed(_value: float) -> void :
	_update_color()


func _on_HSlider_saturation_changed(_value: float) -> void :
	_update_color()


func _on_HSlider_value_changed(_value: float) -> void :
	_update_color()


func _update_color():
	var new_color: Color = Color.from_hsv(slider_hue.value, slider_saturation.value, slider_value.value)
	_update_slider_color(new_color)
	emit_signal("color_changed", new_color)

func _update_slider_color(new_color: Color) -> void :
	rect_color.color = new_color
	ramp_value.colors[1] = Color.from_hsv(slider_hue.value, new_color.s, 1)
	ramp_saturation.colors[0] = Color.from_hsv(slider_hue.value, 0, new_color.v)
	ramp_saturation.colors[1] = Color.from_hsv(slider_hue.value, 1, new_color.v)


func _on_reset_but_pressed():
	emit_signal("color_reset")
