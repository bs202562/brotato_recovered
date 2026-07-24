class_name EelPivots
extends Node2D

onready var bullets_far = $BulletsFar
onready var bullets_close = $BulletsClose


func _ready():
	var specific_direction = Utils.get_rand_element([ - 1, 1])
	for p in bullets_far.get_children():
		p.direction = specific_direction
	for p in bullets_close.get_children():
		p.direction = specific_direction


func free_pivots() -> void :
	bullets_far.queue_free()
	bullets_close.queue_free()


func get_bullets() -> Array:
	var bullets = []

	for p in bullets_far.get_children():
		bullets.append_array(p.get_children())
	for p in bullets_close.get_children():
		bullets.append_array(p.get_children())

	return bullets
