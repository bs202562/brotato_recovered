extends Reference
# Attached presentation only; observes original CPU particle emitters.
func update(source,visual,factory,renderer):
	if not source is Weapon or source.weapon_id!="weapon_torch":return
	var emitter=source.muzzle.get_node_or_null("BurningParticles")
	var root=visual.get_node_or_null("TorchFlame3D")
	if not emitter is CPUParticles2D:
		if root!=null:root.visible=false
		return
	if root==null:
		root=create(factory,visual)
	var angle=source.sprite.global_rotation
	root.visible=true
	root.global_transform=Transform(Basis(Vector3.UP,-atan2(sin(angle)/sin(renderer.TILT),cos(angle))),renderer.to_world(emitter.global_position,0.65))
	var visible=emitter.is_visible_in_tree()
	var flame_active=visible and emitter.emitting
	var ember=emitter.get_node_or_null("CPUParticles2D")
	var ember_active=visible and ember!=null and ember.is_visible_in_tree() and ember.emitting
	# Deterministic presentation flicker; original emitters still own their timing.
	animate(root,renderer.elapsed,flame_active,ember_active)
	root.set_meta("source_emitter_position",emitter.global_position)

# Shared icon/battle API. Local origin is explicit; no Main or source needed.
func create(factory,parent,local_origin=Vector3.ZERO):
	var root=Spatial.new()
	root.name="TorchFlame3D"
	parent.add_child(root)
	var tongues=Spatial.new()
	tongues.name="Flames"
	root.add_child(tongues)
	for i in range(3):
		factory.ball(tongues,Vector3((i-1)*0.055,0.12+i*0.035,0),Vector3(0.12,0.3-i*0.03,0.12),Color("db692b"))
	factory.ball(tongues,Vector3(0,0.085,0),Vector3(0.11,0.18,0.11),Color("ffd681"),true)
	var glow=factory.ball(root,Vector3.ZERO,Vector3.ONE*0.075,Color("f4ae4f"),true)
	glow.name="EmberCore"
	root.translation=local_origin
	root.set_meta("presentation_fx",true)
	return root
func animate(root,time,flame_emitting=true,ember_emitting=true):
	root.get_node("Flames").visible=flame_emitting
	root.get_node("EmberCore").visible=ember_emitting
	root.get_node("Flames").scale=Vector3(1,1+0.10*sin(time*17),1)
