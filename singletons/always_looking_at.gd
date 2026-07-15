extends Node2D

@export var direction: Vector2 = Vector2(0, - 1)

func _process(_delta):
	look_at(global_position + direction)
