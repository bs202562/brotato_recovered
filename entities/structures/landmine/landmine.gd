class_name Landmine
extends Structure

@export var pressed_sprite: Resource = null
@export var pressed_sounds: Array = [] # (Array, Resource)

@onready var _sprite = $Animation / Sprite2D
@onready var _original_texture = _sprite.texture

var _original_effects: Array
var _explode_args_landmine: = WeaponServiceExplodeArgs.new()


func respawn() -> void :
	super.respawn()
	_sprite.texture = _original_texture


func _on_Area2D_body_entered(_body: Node) -> void :

	if dead or _sprite.texture == pressed_sprite: return

	SoundManager2D.play(Utils.get_rand_element(pressed_sounds), global_position, 5, 0.2)
	_sprite.texture = pressed_sprite


func _on_Area2D_body_exited(_body: Node) -> void :
	call_deferred("explode")


func explode() -> void :
	if dead or effects.size() <= 0: return

	var explosion_effect = effects[0]

	_explode_args_landmine.pos = global_position
	_explode_args_landmine.damage = stats.damage
	_explode_args_landmine.accuracy = stats.accuracy
	_explode_args_landmine.crit_chance = stats.crit_chance
	_explode_args_landmine.crit_damage = stats.crit_damage
	_explode_args_landmine.burning_data = stats.burning_data
	_explode_args_landmine.scaling_stats = stats.scaling_stats
	_explode_args_landmine.from_player_index = player_index
	_explode_args_landmine.damage_tracking_key_hash = explosion_effect.tracking_key_hash
	_explode_args_landmine.from = self
	var _inst = WeaponService.explode(explosion_effect, _explode_args_landmine)
	die()

func die(args = Utils.default_die_args) -> void :
	assert ( not dead)
	if is_instance_valid(curse_particle_instance):
		curse_particle_instance.queue_free()

	_collision.disabled = true

	cleaning_up = args.cleaning_up
	_animation_player.speed_scale = 1
	dead = true
	_animation_player.play("death")
	emit_signal("died", self, args)

func boost(boost_args: BoostArgs) -> void :
	if can_be_boosted:
		super.boost(boost_args)
		stats.damage *= 1.0 + boost_args.damage_boost / 100.0

		_original_effects = effects
		var new_explosion_effect = effects[0].duplicate()
		new_explosion_effect.scale *= 1.0 + boost_args.range_boost / 100.0
		effects = [new_explosion_effect]


func boost_ended() -> void :
	super.boost_ended()
	effects = _original_effects


func set_data(data: Resource) -> void :
	super.set_data(data)

	if data.is_cursed:
		curse_particle_instance = curse_particles.instance()
		add_child(curse_particle_instance)
		add_outline(Utils.CURSE_COLOR)
