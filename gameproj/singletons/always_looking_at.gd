extends Node2D

export (Vector2) var direction = Vector2(0, - 1)

func _process(_delta):
	look_at(global_position + direction)
