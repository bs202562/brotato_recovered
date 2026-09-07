extends Reference
# Thin corner brackets identify the player through a crowded model silhouette.
# No filled disc or radius cue: this is a locator, not a collision indicator.
static func attach(visual, player_index, factory):
	var root=Spatial.new()
	root.name="PlayerLocator3D"
	root.scale=Vector3.ONE/visual.scale
	visual.add_child(root)
	var mat=SpatialMaterial.new()
	mat.flags_unshaded=true
	mat.flags_no_depth_test=true
	# Transparent pass honors priority after opaque enemy meshes; no filled face.
	mat.flags_transparent=true
	mat.params_cull_mode=SpatialMaterial.CULL_DISABLED
	mat.albedo_color=CoopService.get_player_color(player_index)
	mat.render_priority=20
	for x in [-1,1]:
		for z in [-1,1]:
			var a=factory.box(root,Vector3(x*0.5,0.1,z*0.64),Vector3(0.28,0.035,0.055),Color.white)
			var b=factory.box(root,Vector3(x*0.64,0.1,z*0.5),Vector3(0.055,0.035,0.28),Color.white)
			a.material_override=mat
			b.material_override=mat
	return root
