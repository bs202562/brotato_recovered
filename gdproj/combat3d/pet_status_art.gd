extends Reference
# Observes existing aura membership / block animation; no gameplay state writes.
func update(source,visual,factory,tilt):
	if source is DocMoth:
		var ring=visual.get_node_or_null("HealingBoostZone3D")
		if ring==null:
			ring=_ring(visual,"HealingBoostZone3D",factory,Color("57ba93"))
		var shape=source._boost_zone.get_node("CollisionShape2D")
		var radius=shape.shape.radius*abs(shape.global_scale.x)/64.0
		ring.rotation.y=-visual.rotation.y
		ring.scale=Vector3(radius,1,radius/sin(tilt))/visual.scale
		visual.set_meta("healing_boost_radius",radius)
	elif source is Player:
		var active=not source.inside_doc_moth_area.empty()
		var marker=visual.get_node_or_null("HealingBoostActive3D")
		if marker==null and active:
			marker=Spatial.new()
			marker.name="HealingBoostActive3D"
			visual.add_child(marker)
			factory.box(marker,Vector3(0,1.4,0),Vector3(0.07,0.29,0.06),Color("70d9a8"),true)
			factory.box(marker,Vector3(0,1.4,0),Vector3(0.24,0.07,0.06),Color("70d9a8"),true)
		if marker!=null:marker.visible=active
		visual.set_meta("healing_boost_active",active)
	elif source is Jellyshield:
		var active=source._animation_player.current_animation=="hit"
		var ring=visual.get_node_or_null("ShieldBlock3D")
		if ring==null and active:
			ring=_ring(visual,"ShieldBlock3D",factory,Color("a8eef4"))
			ring.scale=Vector3(0.46,1,0.46)/visual.scale
		if ring!=null:ring.visible=active
		visual.set_meta("shield_block_active",active)
func _ring(visual,name,factory,color):
	var root=Spatial.new()
	root.name=name
	visual.add_child(root)
	for i in range(32):
		var angle=TAU*i/32.0
		var part=factory.box(root,Vector3(cos(angle),0.08,sin(angle)),Vector3(0.18,0.025,0.025),color,true)
		part.rotation.y=-angle+PI/2
	return root
