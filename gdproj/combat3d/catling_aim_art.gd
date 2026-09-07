extends Reference
# Two independent visual barrels; the existing source remains the sole aimer/shooter.
func update(source,visual,factory,renderer):
	if not source is CatlingGun:return
	for side in ["L","R"]:
		var gun=visual.get_node_or_null("CatlingGun3D"+side)
		if gun==null:
			gun=Spatial.new()
			gun.name="CatlingGun3D"+side
			visual.add_child(gun)
			factory.box(gun,Vector3(-0.32,0,0),Vector3(0.42,0.14,0.15),Color("334950"))
			factory.box(gun,Vector3(-0.12,0,0),Vector3(0.22,0.075,0.09),Color("8babad"))
			factory.box(gun,Vector3(-0.38,-0.08,0),Vector3(0.11,0.15,0.10),Color("bd9256"))
		var pivot=source._gun_pivot_l if side=="L" else source._gun_pivot_r
		var muzzle=source._left_muzzle if side=="L" else source._right_muzzle
		# Source's mirrored pose encodes target angle as 180-angle (integer degrees).
		var angle=PI-pivot.rotation if source.sprite.scale.x<0 else pivot.rotation
		var yaw=-atan2(sin(angle)/sin(renderer.TILT),cos(angle))
		# Exact same original muzzle expression used by CatlingGun.shoot().
		var pos=source._animation.global_position+muzzle.global_position-Vector2(100,100)
		gun.global_transform=Transform(Basis(Vector3.UP,yaw),renderer.to_world(pos,0.65))
		gun.set_meta("source_muzzle",pos)
		gun.set_meta("source_aim_angle",angle)
