extends Reference
# Authored utility objects, companions and projectile silhouettes.
const PETS = ["scapegoat","ratzilla","lootworm","jellyshield","blazemander","bot_o_mine","bonk_dog","catling_gun","doc_moth"]
var f
var metal = Color("627d83")
var dark = Color("263b46")
var amber = Color("e9ae51")
var teal = Color("69d8c9")

func build(factory,kind,identity):
	f = factory
	var root = Spatial.new()
	root.set_meta("art_identity",identity)
	match kind:
		"structure": _structure(root,identity)
		"pet": _pet(root,identity.get_file().get_basename())
		"tree": _planter(root)
		"consumable": _supply(root,identity)
		"material":
			f.box(root,Vector3(0,0.12,0),Vector3(0.2,0.19,0.16),dark)
			f.box(root,Vector3(0,0.22,0),Vector3(0.13,0.045,0.1),metal)
			f.box(root,Vector3(0,0.13,0.09),Vector3(0.14,0.08,0.025),teal,true)
		"projectile", "enemy_projectile": _projectile(root,identity,kind=="enemy_projectile")
		"birth": ring(root,0.32,Color("d96157"),0.035)
		"explosion":
			_explosion(root)
		_:
			root.free()
			return null
	return root

func cylinder(root,pos,radius,height,color):
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return f.part(root,mesh,pos,color)

func _explosion(root):
	# Shaded lobes retain volume instead of saturating the whole blast to yellow.
	for i in range(7):
		var angle = i * TAU / 7.0
		var radius = 0.13 if i % 2 == 0 else 0.19
		var size = 0.26 if i % 2 == 0 else 0.21
		var color = Color("df682c") if i % 2 == 0 else Color("ae4927")
		f.ball(root,Vector3(cos(angle)*radius,0.17+0.035*(i%3),sin(angle)*radius),Vector3(size,size*1.35,size),color)
	f.ball(root,Vector3(0,0.25,0),Vector3(0.26,0.30,0.26),Color("ffbe61"))
	f.ball(root,Vector3(0,0.32,0),Vector3(0.12,0.13,0.12),Color("fff0b4"),true)
	# One continuous annulus marks the blast radius without a chunky tiled rim.
	var mesh = ImmediateGeometry.new()
	mesh.material_override = f.material(Color("eaaa56"))
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(48):
		var a = i * TAU / 48.0
		var b = (i+1) * TAU / 48.0
		var outer_a = Vector3(cos(a)*0.46,0.025,sin(a)*0.46)
		var inner_a = Vector3(cos(a)*0.445,0.025,sin(a)*0.445)
		var outer_b = Vector3(cos(b)*0.46,0.025,sin(b)*0.46)
		var inner_b = Vector3(cos(b)*0.445,0.025,sin(b)*0.445)
		for point in [outer_a,outer_b,inner_a,outer_b,inner_b,inner_a]:
			mesh.set_normal(Vector3.UP)
			mesh.add_vertex(point)
	mesh.end()
	root.add_child(mesh)

func ring(root,radius,color,width=0.035):
	for i in range(16):
		var angle = i*TAU/16
		var part = f.box(root,Vector3(cos(angle)*radius,0.025,sin(angle)*radius),Vector3(width,0.025,radius*0.4),color,true)
		part.rotation.y = -angle

func _structure(root,id):
	if "landmine" in id:
		cylinder(root,Vector3(0,0.07,0),0.3,0.14,dark)
		cylinder(root,Vector3(0,0.15,0),0.21,0.07,amber)
		f.ball(root,Vector3(0,0.2,0),Vector3(0.12,0.05,0.12),Color("ed6556"),true)
		return
	if "garden" in id:
		f.box(root,Vector3(0,0.16,0),Vector3(0.85,0.32,0.68),metal)
		f.box(root,Vector3(0,0.33,0),Vector3(0.75,0.045,0.58),Color("463e37"))
		for i in range(4):
			var pos = Vector3((i%2-0.5)*0.35,0.48,(i/2-0.5)*0.28)
			f.ball(root,pos,Vector3(0.26,0.3,0.27),Color("75a36b"))
			f.ball(root,pos+Vector3(0,0.06,0.09),Vector3.ONE*0.11,Color("dd8560"))
		return
	var healing = "healing" in id
	var laser = "laser" in id
	var flame = "flame" in id
	var rocket = "rocket" in id
	var accent = teal if healing or laser else amber
	for side in [-1,1]:
		f.box(root,Vector3(side*0.28,0.1,0),Vector3(0.16,0.16,0.68),dark)
		for z in [-0.23,0,0.23]: cylinder(root,Vector3(side*0.28,0.13,z),0.08,0.07,metal).rotation.z = PI/2
	cylinder(root,Vector3(0,0.22,0),0.25,0.24,metal)
	f.box(root,Vector3(0,0.46,0),Vector3(0.5,0.33,0.42),accent)
	f.box(root,Vector3(0,0.58,0.22),Vector3(0.19,0.08,0.035),teal,true)
	if healing:
		f.box(root,Vector3(0,0.67,0),Vector3(0.31,0.08,0.13),Color("e0e8d7"))
		f.box(root,Vector3(0,0.67,0),Vector3(0.09,0.08,0.34),Color("e0e8d7"))
		ring(root,0.34,teal)
	elif rocket:
		for side in [-1,1]:
			f.box(root,Vector3(side*0.24,0.6,-0.1),Vector3(0.19,0.23,0.64),dark)
			f.ball(root,Vector3(side*0.24,0.6,-0.44),Vector3(0.12,0.12,0.16),Color("dc7454"))
	elif flame:
		for side in [-1,1]: cylinder(root,Vector3(side*0.25,0.48,0.19),0.12,0.4,Color("c86d48"))
		f.box(root,Vector3(0,0.53,-0.36),Vector3(0.17,0.16,0.58),dark)
		f.ball(root,Vector3(0,0.53,-0.65),Vector3.ONE*0.09,amber,true)
	elif laser:
		f.box(root,Vector3(0,0.55,-0.32),Vector3(0.15,0.15,0.52),dark)
		for z in [-0.15,-0.28,-0.41]: f.box(root,Vector3(0,0.64,z),Vector3(0.22,0.07,0.06),teal,true)
	else:
		for side in [-1,1]: f.box(root,Vector3(side*0.12,0.53,-0.33),Vector3(0.08,0.09,0.56),dark)
		if "builder" in id or "tyler" in id:
			f.box(root,Vector3(0,0.72,0.08),Vector3(0.58,0.09,0.44),metal)
			f.box(root,Vector3(0.23,0.83,0.1),Vector3(0.035,0.35,0.035),dark)

func _planter(root):
	cylinder(root,Vector3(0,0.22,0),0.35,0.44,metal)
	cylinder(root,Vector3(0,0.44,0),0.38,0.08,amber)
	cylinder(root,Vector3(0,0.86,0),0.07,0.8,Color("77634d"))
	for i in range(7):
		var angle = i*TAU/7
		var leaf = f.ball(root,Vector3(cos(angle)*0.26,1.08,sin(angle)*0.26),Vector3(0.31,0.14,0.73),Color("5f9276"))
		leaf.rotation = Vector3(-0.3,-angle+PI/2,0)
	f.ball(root,Vector3(0,1.25,0),Vector3(0.34,0.37,0.32),Color("8bb384"))

func _supply(root,id):
	# Distinct temporary silhouettes until their independent GLBs are produced.
	if id == "consumable_poisoned_fruit":
		f.ball(root,Vector3(0,0.22,0),Vector3(0.43,0.4,0.41),Color("532d69"))
		f.ball(root,Vector3(0.09,0.25,0.02),Vector3(0.3,0.32,0.32),Color("683b7b"))
		f.box(root,Vector3(0,0.45,0),Vector3(0.05,0.13,0.055),Color("4c4934"))
		var leaf = f.ball(root,Vector3(0.08,0.47,0),Vector3(0.19,0.04,0.09),Color("73864b"))
		leaf.rotation_degrees.z = 18
		for spot in [Vector3(-0.09,0.28,0.18),Vector3(0.08,0.17,0.19),Vector3(0.16,0.3,0.13),Vector3(-0.04,0.38,0.08)]:
			f.ball(root,spot,Vector3(0.075,0.07,0.045),Color("d3ce61"))
		return
	if id == "consumable_cursed_chest":
		f.box(root,Vector3(0,0.2,0),Vector3(0.52,0.36,0.4),Color("262235"))
		f.box(root,Vector3(0,0.41,0),Vector3(0.55,0.1,0.43),Color("573765"))
		for side in [-1,1]:
			f.box(root,Vector3(side*0.19,0.25,0),Vector3(0.065,0.45,0.46),Color("78508e"))
			var horn = f.box(root,Vector3(side*0.2,0.49,0),Vector3(0.055,0.16,0.07),Color("b498c4"))
			horn.rotation_degrees.z = -side*25
		var lock = f.box(root,Vector3(0,0.26,0.225),Vector3(0.15,0.15,0.04),Color("b79cce"))
		lock.rotation_degrees.z = 45
		f.box(root,Vector3(0,0.27,0.25),Vector3(0.035,0.07,0.012),Color("2e213c"))
		return
	var crate = "box" in id or "crate" in id
	var color = amber if crate else Color("e0e5d6")
	if "legendary" in id: color = Color("be86de")
	f.box(root,Vector3(0,0.23,0),Vector3(0.5,0.4,0.38),color)
	for side in [-1,1]: f.box(root,Vector3(side*0.19,0.23,0),Vector3(0.055,0.44,0.42),dark)
	f.box(root,Vector3(0,0.46,0),Vector3(0.24,0.06,0.085),dark)
	if not crate:
		var cross_color = Color("de665a") if not "damage" in id else Color("ae70d9")
		f.box(root,Vector3(0,0.24,0.201),Vector3(0.22,0.065,0.025),cross_color)
		f.box(root,Vector3(0,0.24,0.203),Vector3(0.065,0.22,0.025),cross_color)
	else: f.box(root,Vector3(0,0.25,0.22),Vector3(0.2,0.12,0.03),teal,true)

func _pet(root,id):
	var color = Color("c29969")
	if id == "jellyshield":
		f.ball(root,Vector3(0,0.7,0),Vector3(0.66,0.5,0.61),Color("73bdbb"))
		for side in [-1,1]:
			f.ball(root,Vector3(side*0.2,0.33,0),Vector3(0.09,0.52,0.1),teal)
			ring(root,0.35,teal)
	elif id == "bot_o_mine":
		_structure(root,"wandering_bot")
		f.box(root,Vector3(0,0.73,0),Vector3(0.4,0.25,0.32),metal)
	elif id == "doc_moth":
		f.ball(root,Vector3(0,0.65,0),Vector3(0.24,0.51,0.25),Color("dbe3c9"))
		for side in [-1,1]:
			var wing = f.ball(root,Vector3(side*0.29,0.65,0),Vector3(0.54,0.09,0.6),Color("92c7b5"))
			wing.rotation.z = side*0.25
	elif id == "lootworm":
		for i in range(5): f.ball(root,Vector3(0,0.18+i*0.06,0.28-i*0.16),Vector3.ONE*(0.28+i*0.025),Color("bd8978"))
		f.box(root,Vector3(0,0.53,-0.2),Vector3(0.33,0.2,0.32),amber)
	else:
		if id == "blazemander": color = Color("a57759")
		if id == "ratzilla": color = Color("879590")
		if id == "scapegoat": color = Color("d2d3ba")
		if id == "catling_gun": color = Color("738791")
		f.ball(root,Vector3(0,0.39,0),Vector3(0.42,0.39,0.66),color)
		f.ball(root,Vector3(0,0.64,0.28),Vector3(0.43,0.4,0.41),color)
		f.ball(root,Vector3(0,0.56,0.48),Vector3(0.23,0.17,0.2),color.lightened(0.15))
		for side in [-1,1]:
			for z in [-0.2,0.21]: f.box(root,Vector3(side*0.16,0.16,z),Vector3(0.12,0.31,0.14),color.darkened(0.2))
			f.ball(root,Vector3(side*0.19,0.83,0.24),Vector3(0.17,0.24,0.13),color)
			f.ball(root,Vector3(side*0.115,0.67,0.47),Vector3.ONE*0.065,dark)
		f.box(root,Vector3(0,0.39,-0.44),Vector3(0.09,0.09,0.35),color)
		f.box(root,Vector3(0,0.48,0.2),Vector3(0.45,0.09,0.15),teal)
		if id == "catling_gun":
			# Empty mounts: CatlingAimArt attaches independently aimed live barrels.
			for side in [-1,1]: f.box(root,Vector3(side*0.27,0.43,0.02),Vector3(0.13,0.14,0.16),dark)
		elif id == "scapegoat":
			for side in [-1,1]: f.box(root,Vector3(side*0.15,0.96,0.15),Vector3(0.065,0.3,0.065),amber)
		elif id == "blazemander":
			for z in [-0.3,-0.1,0.1]: f.ball(root,Vector3(0,0.61,z),Vector3(0.14,0.22,0.14),amber,true)

func _projectile(root,id,hostile):
	var color = Color("dd758c") if hostile else Color("f5d083")
	if "laser" in id or "rail" in id or "lightning" in id or "taser" in id or "particle" in id:
		color = Color("77dded")
		f.ball(root,Vector3.ZERO,Vector3(0.32,0.026,0.025),color,true)
		f.ball(root,Vector3(0.03,0.01,0),Vector3(0.22,0.014,0.012),Color("effff4"),true)
	elif "flame" in id or "fireball" in id or "wand" in id:
		# Opaque shaded tongues retain depth; only the small hot core emits.
		var blue = "blue" in id
		color = Color("3e80bb") if blue else Color("c44e27")
		f.ball(root,Vector3(-0.035,0,0),Vector3(0.24,0.14,0.14),color)
		for side in [-1,1]:
			var tongue = f.ball(root,Vector3(-0.075,0.025,side*0.035),Vector3(0.17,0.07,0.065),color.lightened(0.08))
			tongue.rotation.y = side*0.3
		f.ball(root,Vector3(0.055,0.025,0),Vector3(0.18,0.115,0.11),Color("81c4e4") if blue else Color("f3aa49"))
		f.ball(root,Vector3(0.085,0.057,0.016),Vector3(0.08,0.045,0.04),Color("d9f4ff") if blue else Color("ffe7ad"),true)
	elif "rocket" in id or "nuclear" in id or "grenade" in id:
		f.ball(root,Vector3.ZERO,Vector3(0.32,0.13,0.13),metal)
		f.ball(root,Vector3(0.13,0,0),Vector3(0.1,0.12,0.12),amber)
		f.box(root,Vector3(-0.12,0,0),Vector3(0.08,0.03,0.22),dark)
	elif "shuriken" in id:
		for i in range(4):
			var blade = f.box(root,Vector3.ZERO,Vector3(0.32,0.025,0.07),metal)
			blade.rotation.y = i*PI/4
	elif "slash" in id:
		# A closed curved blade replaces the dotted crescent, with tapered ends.
		_slash(root, Color("bd4962") if hostile else Color("91b8bd"))
	elif hostile:
		# Preserve the original 0.22 silhouette and red danger coding without
		# saturating its entire surface into a flat pink disc.
		f.ball(root,Vector3.ZERO,Vector3.ONE*0.22,Color("b34360"))
		f.ball(root,Vector3(0.025,0.058,0.055),Vector3(0.12,0.075,0.105),Color("ea8390"))
		f.ball(root,Vector3(0.04,0.083,0.059),Vector3.ONE*0.043,Color("ffbdab"),true)
	else:
		# A narrow tapered tracer stays readable without filling the generous hitbox.
		f.ball(root,Vector3.ZERO,Vector3(0.32,0.035,0.022),color,true)

func _slash(root,color):
	var key = "projectile_slash_volume"
	if not f.meshes.has(key):
		var vertices = []
		var normals = []
		var indices = []
		for i in range(20):
			var a = -1.25 + i*2.5/20.0
			var b = -1.25 + (i+1)*2.5/20.0
			var wa = 0.004 + sin(i*PI/20.0)*0.038
			var wb = 0.004 + sin((i+1)*PI/20.0)*0.038
			var outer_a = Vector3(cos(a)*0.155,0,sin(a)*0.155)
			var outer_b = Vector3(cos(b)*0.155,0,sin(b)*0.155)
			var inner_a = Vector3(cos(a)*(0.155-wa),0,sin(a)*(0.155-wa))
			var inner_b = Vector3(cos(b)*(0.155-wb),0,sin(b)*(0.155-wb))
			for side in [-1,1]:
				var offset = Vector3(0,0.009*side,0)
				var points = [outer_a,outer_b,inner_b,inner_a] if side == 1 else [inner_a,inner_b,outer_b,outer_a]
				_append_quad(vertices,normals,indices,points,Vector3.UP*side,offset)
			_append_quad(vertices,normals,indices,[outer_a+Vector3(0,-0.009,0),outer_b+Vector3(0,-0.009,0),outer_b+Vector3(0,0.009,0),outer_a+Vector3(0,0.009,0)],Vector3(cos((a+b)*0.5),0,sin((a+b)*0.5)),Vector3.ZERO)
			_append_quad(vertices,normals,indices,[inner_b+Vector3(0,-0.009,0),inner_a+Vector3(0,-0.009,0),inner_a+Vector3(0,0.009,0),inner_b+Vector3(0,0.009,0)],-Vector3(cos((a+b)*0.5),0,sin((a+b)*0.5)),Vector3.ZERO)
			if i == 0:
				_append_quad(vertices,normals,indices,[inner_a+Vector3(0,-0.009,0),outer_a+Vector3(0,-0.009,0),outer_a+Vector3(0,0.009,0),inner_a+Vector3(0,0.009,0)],Vector3(sin(a),0,-cos(a)),Vector3.ZERO)
			if i == 19:
				_append_quad(vertices,normals,indices,[outer_b+Vector3(0,-0.009,0),inner_b+Vector3(0,-0.009,0),inner_b+Vector3(0,0.009,0),outer_b+Vector3(0,0.009,0)],Vector3(-sin(b),0,cos(b)),Vector3.ZERO)
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PoolVector3Array(vertices)
		arrays[Mesh.ARRAY_NORMAL] = PoolVector3Array(normals)
		arrays[Mesh.ARRAY_INDEX] = PoolIntArray(indices)
		var mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		f.meshes[key] = mesh
	f.part(root,f.meshes[key],Vector3.ZERO,color)

func _append_quad(vertices,normals,indices,points,normal,offset):
	var start = vertices.size()
	for point in points:
		vertices.append(point+offset)
		normals.append(normal)
	for index in [0,1,2,0,2,3]: indices.append(start+index)
