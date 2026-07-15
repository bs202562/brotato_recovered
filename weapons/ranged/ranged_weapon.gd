class_name RangedWeapon
extends Weapon


func _ready() -> void :
	super._ready() # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_ready 为基类优先；_shooting_behavior 由 Weapon._ready 初始化）
	var _projectile_shot = _shooting_behavior.connect("projectile_shot", Callable(self, "on_projectile_shot"))


func on_projectile_shot(projectile: Node2D) -> void :
	if not is_instance_valid(projectile):
		return

	if effects.size() > 0 or RunData.get_player_effect(Keys.gain_stat_when_attack_killed_enemies_hash, player_index).size() > 0:
		if not projectile.killed_something_connected:
			var _killed_sthing = projectile._hitbox.connect("killed_something", Callable(self, "on_killed_something").bind(projectile._hitbox))
			projectile.killed_something_connected = true

	if not projectile.hit_something_connected:
		var _hit_sthing = projectile.connect("hit_something", Callable(self, "on_weapon_hit_something").bind(projectile._hitbox))
		projectile.hit_something_connected = true

	if not projectile.critically_hit_something_connected:
		var _crit_hit_sthing = projectile.connect("critically_hit_something", Callable(self, "_on_weapon_critically_hit_something"))
		projectile.critically_hit_something_connected = true
