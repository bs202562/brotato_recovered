extends Node2D
class_name BulletsGenerator

var projectile_pool_id: int = Keys.empty_hash

export (int, "NO_ANCHOR", "TOP_LEFT", "TOP_CENTER", "TOP_RIGHT", "CENTER_LEFT", "CENTER", "CENTER_RIGHT", "BOTTOM_LEFT", "BOTTOM_CENTER", "BOTTOM_RIGHT") var anchor_position: int = 0

export (Vector2) var offset_anchor_positon: Vector2 = Vector2(0, 0)
export (PackedScene) var projectile_scene_override
export var start_cool_down: float = 0


export (int, 1, 500) var duplications: int = 1
export (int, "nothing", "horizontal_axis", "vertical_axis") var duplication_constant_along: int = 0
export (Vector2) var duplication_offset_position: Vector2 = Vector2(0, 0)
export (float) var duplication_offset_start_cd: float = 0

export (float, 0, 10) var speed_factor: float = 1
export (float, 0, 10) var spawn_rate_factor: float = 1
export (float, 0, 10) var damage_factor: float = 1
export (Vector2) var direction: Vector2 = Vector2(1, 0)

export (Vector2) var position_spawn_randomness: = Vector2(0, 0)

export (Vector2) var sinusoidal_motion = Vector2(0, 0)
export (Vector2) var sinusoidal_motion_speed = Vector2(5, 5)

export (bool) var is_active: = true

onready var bullet_hell: BulletHell = get_parent()
onready var main: Main = get_tree().current_scene
onready var projectile_scene: PackedScene = projectile_scene_override if projectile_scene_override != null else bullet_hell.projectile_scene



func _ready():
	if projectile_scene != null:
		projectile_pool_id = Keys.generate_hash(projectile_scene.resource_path)


	yield(get_tree(), "idle_frame")
	global_position = ZoneService.get_anchor_position(anchor_position) + offset_anchor_positon

	if duplication_constant_along == 1:
		duplications = 1
		if duplication_offset_position.x > 0:
			duplications = (abs(int(ZoneService.get_current_zone_rect().size.x - global_position.x)) / duplication_offset_position.x) + 1
		if duplication_offset_position.x < 0:
			duplications = (abs(int(global_position.x - ZoneService.get_current_zone_rect().size.x)) / duplication_offset_position.x) + 1
	if duplication_constant_along == 2:
		duplications = 1
		if duplication_offset_position.y > 0:
			duplications = (abs(int(ZoneService.get_current_zone_rect().size.y - global_position.y)) / duplication_offset_position.y) + 1
		if duplication_offset_position.y < 0:
			duplications = (abs(int(global_position.y - ZoneService.get_current_zone_rect().size.y)) / duplication_offset_position.y) + 1

	if is_active:
		for duplication in duplications:
			var spawner: BulletSpawner = BulletSpawner.new()
			add_child(spawner)




func get_base_damage(wave: int) -> float:
	return (bullet_hell.projectile_damage + bullet_hell.projectile_damage_increase_each_wave * (wave - 1)) * damage_factor


func get_random_position_spawning() -> Vector2:
	return Vector2(rand_range( - position_spawn_randomness.x / 2, position_spawn_randomness.x / 2), rand_range( - position_spawn_randomness.y / 2, position_spawn_randomness.y / 2))


class BulletSpawner:
	extends Node2D

	onready var generator: BulletsGenerator = get_parent()
	onready var bullet_hell: BulletHell = generator.bullet_hell
	onready var start_cool_down: float = generator.start_cool_down + (get_index() * generator.duplication_offset_start_cd)
	onready var tick_progression: float = (bullet_hell.spawn_rate * generator.spawn_rate_factor) * start_cool_down
	onready var angle_bullet: float = generator.direction.angle_to_point(Vector2(0, 0))


	func _ready():
		global_position = generator.global_position + (get_index() * generator.duplication_offset_position)


	func _physics_process(delta):
		tick_progression += delta
		while tick_progression > bullet_hell.spawn_rate * generator.spawn_rate_factor:
			tick_progression -= bullet_hell.spawn_rate * generator.spawn_rate_factor
			spawn_projectile(angle_bullet, bullet_hell.projectile_speed * generator.speed_factor)

	func spawn_projectile(rot: float, spd: int) -> Node:
		var main = Utils.get_scene_node()
		var projectile: BulletHellProjectile = main.get_node_from_pool(generator.projectile_pool_id, generator.main._enemy_projectiles)

		if not is_instance_valid(projectile):
			projectile = generator.projectile_scene.instance()
			generator.main.add_enemy_projectile(projectile)
			projectile.set_meta("pool_id", generator.projectile_pool_id)

		projectile.global_position = global_position + generator.get_random_position_spawning()
		projectile.set_from(bullet_hell)
		projectile.velocity = Vector2.RIGHT.rotated(rot) * spd * RunData.current_run_accessibility_settings.speed
		projectile.rotation = rot
		projectile.sinusoidal_motion = generator.sinusoidal_motion
		projectile.sinusoidal_motion_speed = generator.sinusoidal_motion_speed
		projectile.direction = generator.direction

		projectile.set_damage(generator.get_base_damage(RunData.current_wave))

		projectile.shoot()
		return projectile


