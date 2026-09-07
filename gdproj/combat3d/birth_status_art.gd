extends Reference
# Source owns type colors, flicker schedule, collision relocation and lifetime.
func update(source,visual):
	if not source is EntityBirth:return
	var mat
	if not visual.has_meta("birth_instance_material"):
		mat=SpatialMaterial.new()
		mat.flags_unshaded=true
		mat.flags_transparent=true
		for child in visual.get_children():
			if child is MeshInstance:child.material_override=mat
		visual.set_meta("birth_instance_material",mat)
	else:mat=visual.get_meta("birth_instance_material")
	# Ignore the intentionally transparent Births container; observe local source art.
	mat.albedo_color=source._sprite.modulate*source._sprite.self_modulate
	for child in visual.get_children():
		if child is MeshInstance:child.visible=source._sprite.visible
	visual.set_meta("observed_birth_color",mat.albedo_color)
