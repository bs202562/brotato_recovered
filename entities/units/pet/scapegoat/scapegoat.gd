class_name Scapegoat
extends Pet

export (AudioStream) var sound_dying
export (AudioStream) var sound_rising
export (AudioStream) var sound_pet
var revive_duration = 3
onready var audiostream = $"AudioStreamPlayer2D" as AudioStreamPlayer2D
onready var life_bar = $"%LifeBar" as UIProgressBar
onready var heal_particles = $"%heal_particles" as CPUParticles2D

var closed_player_list = []
var _floating_health = 0
const INVULNERABLE_COOLDOWN: float = 0.6
var _invulnerable_cooldown: float = 0.0

var is_scapegoat: = true

func _ready():
	_animation_player.play("move")
	heal_particles.modulate = ProgressData.settings.color_positive
	var _error_hp_lifebar = connect("health_updated", self, "on_health_updated")

func update_data(effect: PetEffect) -> void :
	.update_data(effect)
	revive_duration = effect.revive_duration
	max_stats.health *= effect.health_boost
	current_stats.health *= effect.health_boost
	emit_signal("health_updated", self, current_stats.health, max_stats.health)


func reset_health_stat(percent_modifier: int = 0) -> void :
	current_stats.health = round(stats.get_base_health(RunData.current_wave)) as int
	max_stats.health = current_stats.health

func on_health_updated(_unit: Unit, current_val: int, max_val: int) -> void :
	if ProgressData.settings.hp_bar_on_bosses:
		if not life_bar.visible:
			life_bar.show()

		life_bar.update_value(current_val, max_val)
	elif life_bar.visible:
		life_bar.hide()

func _physics_process(delta) -> void :
	if _end_of_wave:
		return

	if _invulnerable_cooldown > 0 and not dead:
		_invulnerable_cooldown = max(_invulnerable_cooldown - delta, 0)
	elif _invulnerable_cooldown <= 0 and not dead and _hurtbox.is_disabled():
		_hurtbox.enable()

	if dead and closed_player_list.size() > 0:
		if current_stats.health >= max_stats.health:
			heal_particles.emitting = false
			audiostream.playing = false
			_rising()
		else:
			
			var value = (max_stats.health / revive_duration) * delta
			_floating_health += value
			current_stats.health = min(_floating_health, max_stats.health)
			if not heal_particles.emitting:
				heal_particles.emitting = true
				audiostream.playing = true
				_animation_player.play("rising")
			emit_signal("health_updated", self, current_stats.health, max_stats.health)

func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :
	if not hitbox.active or hitbox.ignored_objects.has(self):
		return
	var dmg = hitbox.damage
	var dmg_taken = [0, 0]
	var from = hitbox.from if is_instance_valid(hitbox.from) else null
	var from_player_index = from.player_index if (from != null and "player_index" in from) else RunData.DUMMY_PLAYER_INDEX

	if hitbox.deals_damage:
		var args: = TakeDamageArgs.new(from_player_index, hitbox)
		args.from = from
		dmg_taken = take_damage(1, args)

	hitbox.hit_something(self, dmg_taken[1])
	_hurtbox.disable()
	_invulnerable_cooldown = INVULNERABLE_COOLDOWN

func _rising() -> void :
	dead = false
	_pending_die = false
	_can_move = true
	_floating_health = 0
	_animation_player.play("move")
	SoundManager.play(sound_rising, 0, 0.1)


func die(args: = Entity.DieArgs.new()) -> void :
	_can_move = false
	if not args.cleaning_up:
		SoundManager.play(sound_dying, 0, 0.1)
		
		dead = true
		emit_signal("died", self, args)
		_floating_health = 0
		_animation_player.play("dead")
	else:
		_end_of_wave = true


func _on_HealingTriggeringZone_body_entered(body):
	if _end_of_wave:
		return

	closed_player_list.push_back(body as Player)


func _on_HealingTriggeringZone_body_exited(body):
	closed_player_list.erase(body as Player)
	if closed_player_list.size() <= 0 and heal_particles.emitting:
		heal_particles.emitting = false
		audiostream.playing = false
		_animation_player.play("dead")


func _can_pet():
	var main: Main = get_tree().current_scene
	if main._get_live_players().size() <= 0:
		dead = true
		_can_move = false
		return

	if heal_particles.emitting:
		heal_particles.emitting = false
		audiostream.playing = false
		_animation_player.play("dead")

	if _check_can_be_pet():
		yield(get_tree().create_timer(0.1), "timeout")
		_animation_player.play("pet")
		SoundManager.play(sound_pet, 1, 0)
		yield(get_tree().create_timer(1.45), "timeout")
		_animation_player.play("move")
	elif not dead:
		yield(get_tree().create_timer(0.1), "timeout")
		_animation_player.play("move")
