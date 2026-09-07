extends Reference
# Visual-only adapters. No gameplay callbacks, stats, collisions or RNG are used.
func evolution(visual, stage: int, base_scale: Vector3, factory):
	stage = int(clamp(stage,0,2))
	if visual.get_meta("observed_evolution",-1)==stage: return
	visual.set_meta("observed_evolution",stage)
	visual.scale=base_scale * [1.0,1.18,1.38][stage]
	var old=visual.get_node_or_null("EvolutionSupplies")
	if old!=null:
		visual.remove_child(old)
		old.queue_free()
	var supplies=Spatial.new()
	supplies.name="EvolutionSupplies"
	visual.add_child(supplies)
	# One strapped cache, then three caches make growth legible beyond color.
	if stage==0:return
	for i in range(1 if stage==1 else 3):
		var x=(-0.28 if stage==1 else 0.0) if i==0 else (-0.28 if i==1 else 0.28)
		var y=0.38 if i==0 else 0.23
		factory.box(supplies,Vector3(x,y,0.22),Vector3(0.3,0.3,0.25),Color("746143"))
		factory.box(supplies,Vector3(x,y,0.08),Vector3(0.08,0.31,0.03),Color("dfb765"))
		factory.box(supplies,Vector3(x,y,0.06),Vector3(0.14,0.09,0.035),Color("f4d78d"))

func mine(visual, pressed: bool, base_scale: Vector3, factory, elapsed: float):
	if not visual.has_meta("observed_mine_pressed") or visual.get_meta("observed_mine_pressed")!=pressed:
		visual.set_meta("observed_mine_pressed",pressed)
		visual.scale=base_scale*Vector3(1,0.72 if pressed else 1,1)
		var warning=visual.get_node_or_null("PressedWarning")
		if warning==null:
			warning=Spatial.new()
			warning.name="PressedWarning"
			visual.add_child(warning)
			for i in range(12):
				var a=TAU*i/12.0
				var mark=factory.box(warning,Vector3(cos(a)*0.59,0.14,sin(a)*0.59),Vector3(0.12,0.035,0.05),Color("ff955f"))
				mark.rotation.y=-a
			factory.box(warning,Vector3(0,0.55,0),Vector3(0.09,0.29,0.09),Color("ffd68b"))
			factory.ball(warning,Vector3(0,0.33,0),Vector3(0.11,0.11,0.11),Color("ffd68b"))
		warning.visible=pressed
	if pressed:
		var warning=visual.get_node("PressedWarning")
		var pulse=1.0+0.05*sin(elapsed*12.0)
		warning.scale=Vector3(pulse,1,pulse)
