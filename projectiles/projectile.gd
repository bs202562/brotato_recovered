class_name Projectile
extends Node2D

signal hit_something(thing_hit, damage_dealt)
signal critically_hit_something(thing_hit, damage_dealt)

@export var destroy_on_leaving_screen: bool = true
@export var stop_delay: float = 0.0

@export var sinusoidal_motion: Vector2 = Vector2(0, 0)
@export var sinusoidal_motion_speed: Vector2 = Vector2(5, 5)

var sinusoidal_time: Vector2 = Vector2(0, 0)
var sinusoidal_offset: Vector2 = Vector2(0, 0)

var velocity = Vector2.ZERO

var _enable_stop_delay: = false
var _elapsed_delay: = 0.0
var _original_collision_layer: int
var _original_hitbox_disabled: bool

var killed_something_connected: = false
var hit_something_connected: = false
var critically_hit_something_connected: = false

var _hitbox_args: = Hitbox.HitboxArgs.new()

@onready var _sprite: = $"%Sprite2D" as Sprite2D
@export var clear_material_when_pooled := true
@onready var _hitbox: = $"%Hitbox" as Area2D
@onready var _animation_player: = $"%AnimationPlayer"


func _ready() -> void :
	_original_collision_layer = _hitbox.collision_layer
	_original_hitbox_disabled = _hitbox.is_disabled()


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
	_hitbox.active = true
	if not _original_hitbox_disabled:
		_hitbox.enable()

	if _animation_player.assigned_animation != "":
		_animation_player.play()


func stop() -> void :
	if _enable_stop_delay:
		return

	_hitbox.active = false
	_hitbox.disable()
	_hitbox.ignored_objects.clear()

	if stop_delay > 0:
		_enable_stop_delay = true
	else:
		_return_to_pool()



func _return_to_pool() -> void :
	velocity = Vector2.ZERO
	_hitbox.collision_layer = _original_collision_layer
	_enable_stop_delay = false
	_elapsed_delay = 0
	sinusoidal_time = Vector2.ZERO
	sinusoidal_offset = Vector2.ZERO
	if clear_material_when_pooled:
		_sprite.material = null
	_animation_player.stop()
	killed_something_connected = false;
	hit_something_connected = false;
	critically_hit_something_connected = false;

	Utils.disconnect_all_signal_connections(self, "hit_something")
	Utils.disconnect_all_signal_connections(self._hitbox, "killed_something")
	Utils.disconnect_all_signal_connections(self, "critically_hit_something")

	if is_instance_valid(_hitbox.from) and _hitbox.from.has_signal("died") and _hitbox.from.is_connected("died", Callable(self, "on_entity_died")):
		_hitbox.from.disconnect("died", Callable(self, "on_entity_died"))

	if get_parent() != null:
		Utils.get_scene_node().add_node_to_pool(self, get_meta("pool_id"))


func get_damage() -> int:
	return _hitbox.damage


func set_damage(value: float, hitbox_args: Hitbox.HitboxArgs = _hitbox_args) -> void :
	assert (_hitbox)
	_hitbox.set_damage(value, hitbox_args)


func set_damage_tracking_key(damage_tracking_key: int) -> void :
	assert (_hitbox)
	_hitbox.damage_tracking_key_hash = damage_tracking_key


func set_knockback_vector(knockback_direction: Vector2, knockback_amount: float, knockback_piercing: float) -> void :
	assert (_hitbox)
	_hitbox.set_knockback(knockback_direction, knockback_amount, knockback_piercing)


func set_effect_scale(effect_scale: float) -> void :
	assert (_hitbox)
	_hitbox.effect_scale = effect_scale


func set_speed_percent_modifier(speed_percent_modifier: float) -> void :
	assert (_hitbox)
	_hitbox.speed_percent_modifier = speed_percent_modifier


func set_ignored_objects(objects: Array) -> void :
	_hitbox.ignored_objects = objects


func set_from(from: Node) -> void :
	if _hitbox != null and is_instance_valid(_hitbox):
		_hitbox.from = from


func set_collision_layer(value: int) -> void :
	_hitbox.collision_layer = value


func set_sprite_material(material: ShaderMaterial) -> void :
	_sprite.material = material


func disable_hitbox() -> void :
	_hitbox.disable()


func enable_hitbox() -> void :
	_hitbox.enable()



func on_entity_died(_entity: Entity, _args: Entity.DieArgs) -> void :
	stop()
