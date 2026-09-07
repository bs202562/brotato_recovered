extends Reference
# Two shared meshes, one shared vertex-color material, one draw per live ember.
# Presentation only: source burn state and damage remain in the planar game.
static func create(factory):
	if not factory.meshes.has("burn_tongue"):
		var sphere = SphereMesh.new()
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.radius = 0.5
		sphere.height = 1.0
		factory.meshes["burn_tongue"] = _mesh(sphere,[
			[Vector3.ZERO,Vector3(0.105,0.28,0.10),Color("ce5329")],
			[Vector3(0.025,-0.04,0.032),Vector3(0.065,0.17,0.065),Color("ffc566")]])
		factory.meshes["burn_ash"] = _mesh(sphere,[[Vector3.ZERO,Vector3(0.035,0.05,0.025),Color("6b6861")]])
		var material = SpatialMaterial.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.95
		factory.materials["burn_vertex_color"] = material
	var node = MeshInstance.new()
	node.mesh = factory.meshes["burn_tongue"]
	node.material_override = factory.materials["burn_vertex_color"]
	node.cast_shadow = GeometryInstance.SHADOW_CASTING_SETTING_OFF
	node.set_meta("ash_mesh",factory.meshes["burn_ash"])
	return node

static func update(node,progress):
	if progress >= 0.7:
		node.mesh = node.get_meta("ash_mesh")
		node.scale = Vector3.ONE * max(0.1,(1.0-progress)/0.3)
	else:
		var taper = 1.0-progress*0.7
		node.scale = Vector3(taper,0.75+sin(progress*PI/0.7)*0.4,taper)

static func _mesh(sphere,lobes):
	var source = sphere.get_mesh_arrays()
	var vertices = PoolVector3Array()
	var normals = PoolVector3Array()
	var colors = PoolColorArray()
	var indices = PoolIntArray()
	for lobe in lobes:
		var start = vertices.size()
		for i in range(source[Mesh.ARRAY_VERTEX].size()):
			vertices.append(source[Mesh.ARRAY_VERTEX][i]*lobe[1]+lobe[0])
			normals.append((source[Mesh.ARRAY_NORMAL][i]/lobe[1]).normalized())
			colors.append(lobe[2])
		for index in source[Mesh.ARRAY_INDEX]: indices.append(start+index)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
