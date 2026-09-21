class_name RangedWeapon
extends Weapon


func _ready() -> void :
	var _projectile_shot = _shooting_behavior.connect("projectile_shot", self, "on_projectile_shot")


func on_projectile_shot(projectile: Node2D) -> void :
	if not is_instance_valid(projectile):
		return

	if effects.size() > 0 or RunData.get_player_effect(Keys.gain_stat_when_attack_killed_enemies_hash, player_index).size() > 0:
		if not projectile.killed_something_connected:
			var _killed_sthing = projectile._hitbox.connect("killed_something", self, "on_killed_something", [projectile._hitbox])
			projectile.killed_something_connected = true

	if not projectile.hit_something_connected:
		var _hit_sthing = projectile.connect("hit_something", self, "on_weapon_hit_something", [projectile._hitbox])
		projectile.hit_something_connected = true

	if not projectile.critically_hit_something_connected:
		var _crit_hit_sthing = projectile.connect("critically_hit_something", self, "_on_weapon_critically_hit_something")
		projectile.critically_hit_something_connected = true
