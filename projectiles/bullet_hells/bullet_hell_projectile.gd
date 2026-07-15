extends EnemyProjectile
class_name BulletHellProjectile

var direction
const MARGIN = 100

func _physics_process(delta):
	rotation = Vector2(1, 0).angle_to(velocity + sinusoidal_offset)

	if direction == Vector2(1, 0):
		if global_position.x > ZoneService.current_zone_max_position.x + MARGIN:
			stop()
	elif direction == Vector2( - 1, 0):
		if global_position.x < ZoneService.current_zone_min_position.x - MARGIN:
			stop()
	elif direction == Vector2(0, 1):
		if global_position.y > ZoneService.current_zone_max_position.y + MARGIN:
			stop()
	elif direction == Vector2(0, - 1):
		if global_position.y < ZoneService.current_zone_min_position.y - MARGIN:
			stop()
	else:
		printerr("BulletHellProjectile direction not managed")

	super._physics_process(delta) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_physics_process 为子类优先）
