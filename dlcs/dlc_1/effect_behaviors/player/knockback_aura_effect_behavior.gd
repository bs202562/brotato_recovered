class_name KnockbackAuraEffectBehavior
extends PlayerEffectBehavior

export (AudioStreamSample) var sound_effect

var enemies_in_aura: = []

onready var knockback_timer: Timer = $"%KnockbackTimer"
onready var _hitbox: Hitbox = $"%Hitbox"
onready var _animation_player: AnimationPlayer = $"%AnimationPlayer"


func _ready() -> void :
	knockback_timer.wait_time = RunData.get_player_effect(Keys.knockback_aura_hash, _player_index)
	knockback_timer.start()


func should_add_on_spawn() -> bool:
	return RunData.get_player_effect_bool(Keys.knockback_aura_hash, _player_index)


func on_death(_die_args: Entity.DieArgs) -> void :
	knockback_timer.stop()


func _on_Hitbox_body_entered(body: Node) -> void :
	enemies_in_aura.push_back(body)


func _on_Hitbox_body_exited(body: Node) -> void :
	enemies_in_aura.erase(body)


func _on_KnockbackTimer_timeout() -> void :
	if _parent.dead or _parent.cleaning_up:
		return

	var knockback_amount: float = max(1.0, Utils.get_stat(Keys.knockback_hash, _player_index))
	if RunData.get_player_effect_bool(Keys.negative_knockback_hash, _player_index):
		knockback_amount *= - 1

	for enemy in enemies_in_aura:
		if knockback_amount < 0:
			knockback_amount = enemy.get_knockback_amount_based_on_distance_to_attacker(knockback_amount, _hitbox, _parent)
		var knockback_direction: Vector2 = _parent.position.direction_to(enemy.position)
		enemy.knockback_vector = knockback_amount * knockback_direction

	_animation_player.play("knockback")
	SoundManager.play(sound_effect, - 10, 0.1)
