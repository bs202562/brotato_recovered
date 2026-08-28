class_name Lootworm
extends Pet

export (float) var double_chance = 0.05
export (String) var material_gained_tracking_id
export (Resource) var weapon_stats
export (float) var tree_damage_ratio = 5
export (AudioStream) var pet_audio

onready var _hitbox: = $Hitbox as Hitbox
var _is_shooting = false
var _current_weapon_stats = null
var _current_cooldown: = 0
var _closed_trees = []

var _material_gained_tracking_id_hash: int = Keys.empty_hash

func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	_hitbox.from = self
	init_stats()
	_material_gained_tracking_id_hash = Keys.generate_hash(material_gained_tracking_id)
	_hitbox.disable()
	_hitbox.deals_damage = false

func init_stats(at_wave_begin: bool = true) -> void :
	var args: = WeaponServiceInitStatsArgs.new()
	_current_weapon_stats = WeaponService.init_melee_pet_stats(weapon_stats, player_index, args)
	_hitbox.projectiles_on_hit = []
	_current_weapon_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(_current_weapon_stats)
	_hitbox.effect_scale = _current_weapon_stats.effect_scale
	_hitbox.set_damage(_current_weapon_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = _current_weapon_stats.speed_percent_modifier
	_hitbox.from = self

	_current_cooldown = _current_weapon_stats.cooldown

func update_data(effect: PetEffect) -> void :
	.update_data(effect)
	double_chance = effect.double_chance

func _physics_process(delta: float) -> void :
	if not _is_shooting:
		_current_cooldown = max(_current_cooldown - Utils.physics_one(delta), 0)

	if _current_cooldown <= 0 and not _is_shooting and _closed_trees.size() > 0:
		_is_shooting = true
		_hitbox.enable()
		_hitbox.deals_damage = true
	elif _is_shooting:
		_hitbox.ignored_objects.clear()
		_hitbox.disable()
		_current_cooldown = _current_weapon_stats.cooldown
		_is_shooting = false

func _on_ItemAttractArea_area_entered(item: Item) -> void :
	var should_attract_item: = item is Gold
	if not should_attract_item:
		return
	var item_already_attracted_by_player: = item.attracted_by != null
	if should_attract_item and not item_already_attracted_by_player:
		item.attracted_by = self

func _on_ItemPickUpArea_area_entered(area: Area2D) -> void :
	if area is Gold:
		var gold = area as Gold
		if Utils.get_chance_success(double_chance):
			RunData.add_tracked_value(player_index, _material_gained_tracking_id_hash, gold.value)
			gold.value *= 2
			gold.boosted *= 2
		gold.pickup(player_index)
		_animation_player.play("eat")

		yield(_animation_player, "animation_finished")
		_animation_player.current_animation = "idle"


func update_animation(movement: Vector2) -> void :
	.update_animation(movement)
	if movement.length() > 0.1:
		if not (_animation_player.current_animation == "move" or _animation_player.current_animation == "eat" or _animation_player.current_animation == "pet"):
			_animation_player.play("move")
	elif movement.length() <= 0.1:
		if not (_animation_player.current_animation == "idle" or _animation_player.current_animation == "eat" or _animation_player.current_animation == "pet"):
			_animation_player.play("idle")


func _on_TreeArea2D_body_entered(body):
	if not (body is Neutral):
		return

	if body is Neutral:
		if body.max_stats.health > _hitbox.damage * tree_damage_ratio:
			_hitbox.damage = body.max_stats.health / tree_damage_ratio
	if not _closed_trees.has(body):
		_closed_trees.push_back(body)

func _on_TreeArea2D_body_exited(body):
	if not (body is Neutral):
		return

	if _closed_trees.has(body):
		_closed_trees.erase(body)

func _on_Hitbox_hit_something(thing_hit, damage_dealt):
	_hitbox.deals_damage = false

func _can_pet():
	if _check_can_be_pet():
		yield(get_tree().create_timer(0.1), "timeout")
		_animation_player.play("pet")
		SoundManager.play(pet_audio, 1, 0)
		yield(get_tree().create_timer(1.4), "timeout")
		_animation_player.play("idle")
