class_name FlameTurret
extends Turret


func set_current_stats(new_stats: RangedWeaponStats) -> void :
	.set_current_stats(new_stats)
	stats.damage = 1


func reload_data() -> void :
	.reload_data()
	stats.damage = 1
