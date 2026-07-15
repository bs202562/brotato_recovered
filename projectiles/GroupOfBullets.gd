extends Projectile
class_name GroupOfBullet

export (Array, NodePath) var list_of_bullets_path: Array

var list_of_bullets: Array
var dammage_value: int
var hitbox_args: Hitbox.HitboxArgs

func _init():
	for bullet_path in list_of_bullets_path:
		list_of_bullets.push_back(get_node(bullet_path))


func _ready():
	yield(get_tree(), "idle_frame")
	var main: Main = get_tree().current_scene
	for bullet_path in list_of_bullets_path:
		var bullet = get_node(bullet_path)
		main.add_enemy_projectile(bullet)
		bullet.set_meta("pool_id", get_meta("pool_id"))


func set_from(from: Node) -> void :
	for bullet in list_of_bullets:
		bullet.set_from(from)


func set_damage(value: float, hitbox_args: Hitbox.HitboxArgs = _hitbox_args) -> void :
	for bullet in list_of_bullets:
		bullet.set_damage(value, hitbox_args)


func on_entity_died(_entity: Entity, _args: Entity.DieArgs) -> void :
	for bullet in list_of_bullets:
		bullet.on_entity_died(_entity, _args)



func _physics_process(delta: float) -> void :
	if sinusoidal_motion.x != 0 or sinusoidal_motion.y != 0:
		sinusoidal_time += Vector2(delta * sinusoidal_motion_speed.x, delta * sinusoidal_motion_speed.y)
		sinusoidal_offset = Vector2(sin(sinusoidal_time.x), sin(sinusoidal_time.y)) * sinusoidal_motion * 0.5
	position += (velocity + sinusoidal_offset) * delta

	if _enable_stop_delay:
		_elapsed_delay += 60 * delta

		if _elapsed_delay >= stop_delay:
			_return_to_pool()
		return

	if destroy_on_leaving_screen and not ZoneService.current_zone_max_camera_rect.has_point(position):
		stop()


func shoot() -> void :
	for bullet in list_of_bullets:
		bullet.shoot()


func stop() -> void :
	for bullet in list_of_bullets:
		bullet.stop()


func _return_to_pool() -> void :
	for bullet in list_of_bullets:
		bullet._return_to_pool()


func get_damage() -> int:
	return dammage_value


func set_damage_tracking_key(damage_tracking_key: int) -> void :
	for bullet in list_of_bullets:
		bullet.set_damage_tracking_key(damage_tracking_key)


func set_knockback_vector(knockback_direction: Vector2, knockback_amount: float, knockback_piercing: float) -> void :
	for bullet in list_of_bullets:
		bullet.set_damage_tracking_key(knockback_direction, knockback_amount, knockback_piercing)


func set_effect_scale(effect_scale: float) -> void :
	for bullet in list_of_bullets:
		bullet.effect_scale


func set_speed_percent_modifier(speed_percent_modifier: float) -> void :
	for bullet in list_of_bullets:
		bullet.set_speed_percent_modifier(speed_percent_modifier)


func set_ignored_objects(objects: Array) -> void :
	for bullet in list_of_bullets:
		bullet.set_ignored_objects(objects)


func set_collision_layer(value: int) -> void :
	for bullet in list_of_bullets:
		bullet.set_collision_layer(value)


func set_sprite_material(material: ShaderMaterial) -> void :
	for bullet in list_of_bullets:
		bullet.set_sprite_material(material)


func disable_hitbox() -> void :
	for bullet in list_of_bullets:
		bullet.disable_hitbox()


func enable_hitbox() -> void :
	for bullet in list_of_bullets:
		bullet.enable_hitbox()
