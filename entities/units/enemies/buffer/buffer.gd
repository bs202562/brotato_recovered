class_name Buffer
extends Enemy

@export var boost_sound: Resource
@export var nb_entities_boosted_at_once: int = 1
@export var boost_cooldown: float = 4.0
@export var hp_boost: int = 150
@export var damage_boost: int = 25
@export var speed_boost: int = 50
@export var player_hp_boost: int = 20
@export var player_speed_boost: int = 20
@export var player_attack_speed_boost: int = 20
@export var structure_range_boost: int = 20
@export var structure_damage_boost: int = 20
@export var structure_attack_speed_boost: int = 20

var entities_in_zone: = []

@onready var _boost_zone: Area2D = $"%BoostZone"
@onready var _boost_collision: CollisionShape2D = $"%BoostCollision"
@onready var _boost_timer: Timer = $"%BoostTimer"

var _boost_args: = BoostArgs.new()


func _on_BoostZone_body_entered(body: Node) -> void :
	if not dead and body.can_be_boosted:
		entities_in_zone.push_back(body)


func respawn() -> void :
	super.respawn()
	_boost_collision.set_deferred("disabled", false)


func die(args = Utils.default_die_args) -> void :
	super.die(args)
	_boost_collision.set_deferred("disabled", true)
	entities_in_zone.clear()


func _on_BoostTimer_timeout() -> void :
	var nb_entities_boosted = 0
	entities_in_zone.shuffle()
	for entity in entities_in_zone:
		if is_instance_valid(entity) and entity.can_be_boosted and not entity.is_boosted:
			if entity is Player:
				_boost_args.damage_boost = 0
				_boost_args.range_boost = 0
				_boost_args.hp_boost = player_hp_boost
				_boost_args.speed_boost = player_speed_boost
				_boost_args.attack_speed_boost = player_attack_speed_boost

			elif entity is Structure:
				_boost_args.hp_boost = 0
				_boost_args.speed_boost = 0
				_boost_args.damage_boost = structure_damage_boost
				_boost_args.range_boost = structure_range_boost
				_boost_args.attack_speed_boost = structure_attack_speed_boost

			else:
				_boost_args.range_boost = 0
				_boost_args.attack_speed_boost = 0
				_boost_args.hp_boost = hp_boost
				_boost_args.damage_boost = damage_boost
				_boost_args.speed_boost = speed_boost

			entity.boost(_boost_args)
			entity.emit_signal("stats_boosted", entity)

			nb_entities_boosted += 1
			if nb_entities_boosted >= nb_entities_boosted_at_once:
				break

	if nb_entities_boosted > 0:
		emit_signal("stats_boosted", self)
		SoundManager2D.play(boost_sound, global_position, 0.0, 0.2)

	_boost_timer.wait_time = boost_cooldown


func _on_BoostZone_body_exited(body: Node) -> void :
	entities_in_zone.erase(body)
