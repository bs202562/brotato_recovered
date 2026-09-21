class_name Blobfish
extends Enemy

export (PackedScene) var enemy_to_spawn
export (PackedScene) var enemy2_to_spawn

var nb_spawns_on_death = 4


func _on_Hurtbox_area_entered(hitbox: Area2D) -> void :

	if hitbox.from != null and is_instance_valid(hitbox.from):
		if hitbox.from is RangedWeapon:
			nb_spawns_on_death = 4
		elif hitbox.from is MeleeWeapon:
			nb_spawns_on_death = 2
		elif hitbox.from is Pet:
			nb_spawns_on_death = 4 if hitbox.from.shoot_projectiles else 2

	._on_Hurtbox_area_entered(hitbox)


func respawn() -> void :
	.respawn()
	nb_spawns_on_death = 4


func die(args: = Utils.default_die_args) -> void :
	.die(args)

	if args.cleaning_up:
		return

	var charmed_by = get_charmed_by_player_index()
	var nb_to_spawn = nb_spawns_on_death
	var nb_of_enemies_stat = RunData.sum_all_player_effects(Keys.number_of_enemies_hash)

	if nb_of_enemies_stat < 0:
		var nb_to_remove = nb_of_enemies_stat / - 20
		nb_to_spawn = max(2, nb_to_spawn - nb_to_remove)

	for i in nb_to_spawn:
		emit_signal("wanted_to_spawn_an_enemy", enemy_to_spawn, ZoneService.get_rand_pos_in_area(Vector2(global_position.x, global_position.y), 400), self, charmed_by)
	emit_signal("wanted_to_spawn_an_enemy", enemy2_to_spawn, ZoneService.get_rand_pos_in_area(Vector2(global_position.x, global_position.y), 200), self, - 1)
