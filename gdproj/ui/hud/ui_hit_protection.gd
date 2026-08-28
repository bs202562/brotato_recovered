class_name UIHitProtection
extends HBoxContainer


onready var hit_protection_label = $HitProtectionLabel
onready var icon = $Icon


func _ready() -> void :
	hit_protection_label.set_message_translation(false)


func update_value(value: int) -> void :
	hit_protection_label.text = str(value)
