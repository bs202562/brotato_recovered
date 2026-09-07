extends Reference
# Read-only presentation of existing pet animation and ability state.
func update(source,visual,factory):
	if not (source is Blazemander or source is BonkDog or source is CatlingGun or source is Lootworm):return
	var body=visual.get_node_or_null("PetActionBody3D")
	if body==null:
		body=Spatial.new()
		body.name="PetActionBody3D"
		var children=visual.get_children()
		visual.add_child(body)
		for child in children:
			# State observers find their markers at the visual root every frame.
			if child.name in ["CursedStatus3D","RecoveryStatus3D","HealingBoostZone3D","HealingBoostActive3D","ShieldBlock3D","CatlingBoost3D","CatlingGun3DL","CatlingGun3DR"]:continue
			visual.remove_child(child)
			body.add_child(child)
	body.translation=Vector3.ZERO
	body.scale=Vector3.ONE
	var action="idle"
	var anim=source._animation_player
	var t=anim.current_animation_position if anim.is_playing() else 0.0
	if source is Blazemander and anim.current_animation=="attack":
		action="charge"
		var pulse=sin(clamp(t/max(anim.current_animation_length,0.001),0,1)*PI)
		body.scale=Vector3(1+0.16*pulse,1-0.25*pulse,1+0.16*pulse)
	elif source is BonkDog and source._is_jumping:
		action="jump"
		# Lift the child only; root still matches the collision-plane projection.
		body.translation.y=0.85*sin(clamp(t/max(source.charge_duration,0.001),0,1)*PI)
	elif source is Lootworm and anim.current_animation=="eat":
		action="eat"
		var pulse=sin(clamp(t/max(anim.current_animation_length,0.001),0,1)*PI)
		body.scale=Vector3(1+0.3*pulse,1-0.22*pulse,1+0.12*pulse)
	if source is CatlingGun:
		var marker=visual.get_node_or_null("CatlingBoost3D")
		if marker==null and source.is_boosted:
			marker=Spatial.new()
			marker.name="CatlingBoost3D"
			visual.add_child(marker)
			for x in [-1,1]:
				for side in [-1,1]:
					var bar=factory.box(marker,Vector3(x*0.35+side*0.065,1.1,0),Vector3(0.04,0.2,0.04),Color("f2bd65"),true)
					bar.rotation.z=side*0.6
		if marker!=null:marker.visible=source.is_boosted
		if source.is_boosted:action="boost"
	visual.set_meta("pet_observed_action",action)
