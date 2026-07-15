class_name Healer
extends Enemy

@export var heal_sound: Resource
@export var heal: float = 100.0
@export var heal_increase_each_wave: float = 10.0
@export var player_heal: float = 1.0
@export var player_heal_increase_each_wave: float = 0.5

@onready var _boost_zone: Area2D = $"%BoostZone"
@onready var _boost_collision: CollisionShape2D = $"%BoostCollision"


func respawn() -> void :
	super.respawn()
	_boost_collision.set_deferred("disabled", false)


func die(args = Utils.default_die_args) -> void :
	super.die(args)
	_boost_collision.set_deferred("disabled", true)


func _on_BoostZone_body_entered(body: Node) -> void :
	if not dead and ( not body is Structure) and body.current_stats.health < body.max_stats.health:
		SoundManager2D.play(heal_sound, global_position, - 10, 0.2)
		var heal_value = int(player_heal + (RunData.current_wave - 1) * player_heal_increase_each_wave)
		if body is Player:
			body.on_healing_effect(heal_value)

		if body is Enemy:
			body.current_stats.health = min(body.current_stats.health + (heal + (RunData.current_wave - 1) * heal_increase_each_wave), body.max_stats.health)

		if body is Player:
			body.emit_signal("healed", heal_value, body.player_index)
		else:
			body.emit_signal("healed", body)
		emit_signal("healed", self)
