class_name FlameTurret
extends Turret


func set_current_stats(new_stats: RangedWeaponStats) -> void :
	super.set_current_stats(new_stats)
	stats.damage = 1


func reload_data() -> void :
	super.reload_data()
	stats.damage = 1
