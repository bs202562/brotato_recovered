class_name PlayerExplosion
extends Node2D

signal hit_something(thing_hit, damage_dealt)
signal killed_something(thing_killed)


export (Array, Resource) var explosion_sounds
export (float) var sound_db_mod = - 10.0

onready var _sprite: Sprite = $"%Sprite"
onready var _hitbox: Area2D = $"%Hitbox"
onready var _explosion_smoke: RunningSmoke = $"%ExplosionSmoke"
onready var _animation_player: AnimationPlayer = $"%AnimationPlayer"

var player_index: int = - 1
var sound_played = false
var nb_killed = 0
var _hitbox_args = Hitbox.HitboxArgs.new()
var pool_id = Keys.empty_hash


func _ready() -> void :
	var _error: = _animation_player.connect("animation_finished", self, "_on_animation_finished")


func _physics_process(_delta: float) -> void :
	if not sound_played:
		sound_played = true
		set_physics_process(false)
		if sound_db_mod > - 50:
			SoundManager2D.play(Utils.get_rand_element(explosion_sounds), global_position, sound_db_mod, 0.2)


func start_explosion() -> void :
	_hitbox.enable()
	_hitbox.from = self
	_sprite.modulate.a = ProgressData.settings.explosion_opacity
	_animation_player.play("explode")


func end_explosion() -> void :
	_hitbox.disable()
	player_index = - 1
	sound_played = false
	nb_killed = 0
	Utils.disconnect_all_signal_connections(self, "hit_something")
	Utils.disconnect_all_signal_connections(self, "killed_something")
	Utils.get_scene_node().add_node_to_pool(self, pool_id)


func emit_smoke() -> void :
	if ProgressData.settings.visual_effects:
		_explosion_smoke.emit()


func _on_animation_finished(anim_name: String) -> void :
	if anim_name == "explode":
		end_explosion()


func set_damage(args: WeaponServiceExplodeArgs) -> void :
	
	if not is_inside_tree(): return
	_hitbox_args.set_from_explode_args(args)
	_hitbox.set_damage(args.damage, _hitbox_args)
	_hitbox.ignored_objects = args.ignored_objects


func set_area(p_area: float) -> void :
	if not is_inside_tree(): return
	var explosion_scale = max(0.1, p_area + (p_area * (Utils.get_stat(Keys.explosion_size_hash, player_index) / 100.0)))
	scale = Vector2(explosion_scale, explosion_scale)


func set_from(from: Node) -> void :
	if not is_inside_tree(): return
	_hitbox.from = from


func set_smoke_amount(value: int) -> void :
	if not is_inside_tree(): return
	_explosion_smoke.amount = value


func set_damage_tracking_key(damage_tracking_key: int) -> void :
	if not is_inside_tree(): return
	_hitbox.damage_tracking_key_hash = damage_tracking_key


func _on_Hitbox_killed_something(_thing_killed) -> void :
	nb_killed += 1
	emit_signal("killed_something", _thing_killed)
	if nb_killed >= 15:
		ChallengeService.complete_challenge(ChallengeService.chal_fireworks_hash)


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void :
	emit_signal("hit_something", thing_hit, damage_dealt)
