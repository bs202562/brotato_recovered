extends Reference
const WeaponArt = preload("res://combat3d/weapon_art.gd")
const Wardrobe = preload("res://combat3d/survivor_wardrobe.gd")
const PropArt = preload("res://combat3d/prop_art.gd")
# Shared meshes/materials keep the fallback army inexpensive. Imported GLBs
# replace these silhouettes through models.json without changing game rules.
var materials = {}
var models = {}
var meshes = {}
var manifest = {}
var prop_keys = {}

func _init():
	var file = File.new()
	if file.open("res://combat3d/models.json", File.READ) == OK:
		var result = JSON.parse(file.get_as_text())
		if result.error == OK:
			manifest = result.result
		file.close()
	if file.open("res://combat3d/prop_catalog.json", File.READ) == OK:
		var result = JSON.parse(file.get_as_text())
		if result.error == OK:
			for prop_key in result.result:
				var entry = result.result[prop_key]
				prop_keys[str(entry.kind) + "|" + str(entry.identity)] = "prop:" + prop_key
		file.close()

func material(color: Color, glow = false):
	var key = str(color) + str(glow)
	if not materials.has(key):
		var mat = SpatialMaterial.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		if glow:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy = 1.7
		materials[key] = mat
	return materials[key]

func box(parent, pos: Vector3, size: Vector3, color: Color, glow = false):
	var key = "box" + str(size)
	if not meshes.has(key):
		var mesh = CubeMesh.new()
		mesh.size = size
		meshes[key] = mesh
	return part(parent, meshes[key], pos, color, glow)

func ball(parent, pos: Vector3, size: Vector3, color: Color, glow = false):
	if not meshes.has("ball"):
		var mesh = SphereMesh.new()
		mesh.radial_segments = 10
		mesh.rings = 5
		mesh.radius = 0.5
		mesh.height = 1.0
		meshes["ball"] = mesh
	var node = part(parent, meshes["ball"], pos, color, glow)
	node.scale = size
	return node

func part(parent, mesh, pos, color, glow = false):
	var node = MeshInstance.new()
	node.mesh = mesh
	node.material_override = material(color, glow)
	node.translation = pos
	parent.add_child(node)
	return node

func create(kind: String, asset_key = ""):
	var root = Spatial.new()
	var key = asset_key if manifest.has(asset_key) else kind
	var prop_key = prop_keys.get(kind + "|" + asset_key, "")
	if not manifest.has(asset_key) and manifest.has(prop_key): key = prop_key
	if manifest.has(key) and manifest[key].has("recipe") and not manifest[key].has("path"):
		root.free()
		return _bio_visual(key, manifest[key])
	if manifest.has(key) and manifest[key].has("path"):
		var entry = manifest[key]
		var path = entry.path
		if ResourceLoader.exists(path):
			if not models.has(path):
				models[path] = load(path)
			if models[path] is PackedScene:
				var model = models[path].instance()
				root.add_child(model)
				model.scale = Vector3.ONE * float(entry.get("scale", 1.0))
				model.rotation_degrees.y = float(entry.get("yaw", 0.0))
				if entry.has("rotation"):
					model.rotation_degrees = Vector3(entry.rotation[0], entry.rotation[1], entry.rotation[2])
				model.translation.y = float(entry.get("offset_y", 0.0))
				# Studio exports can contain an editor placement on Armature.
				# Center all geometry and place its soles on the logical ground.
				var skeleton = Wardrobe.new().skeleton_in(model)
				if skeleton != null:
					# A skinned mesh AABB includes bind-space offsets, so use the
					# rig origin rather than counting the Armature placement twice.
					var rig_transform = Transform.IDENTITY
					var ancestor = skeleton
					while ancestor != root:
						if ancestor is Spatial: rig_transform = ancestor.transform * rig_transform
						ancestor = ancestor.get_parent()
					model.translation -= rig_transform.origin
					model.translation.y += float(entry.get("offset_y", 0.0))
				else:
					var boxes = []
					_mesh_bounds(model, Transform.IDENTITY, boxes)
					if boxes.size() > 0:
						var bounds = boxes[0]
						for index in range(1, boxes.size()): bounds = bounds.merge(boxes[index])
						model.translation -= Vector3(bounds.position.x + bounds.size.x * 0.5, bounds.position.y - float(entry.get("offset_y", 0.0)), bounds.position.z + bounds.size.z * 0.5)
				var animator = find_animator(model)
				if animator != null and animator.get_animation_list().size() > 0:
					var clip = entry.get("animation", "")
					if not animator.has_animation(clip): clip = animator.get_animation_list()[0]
					animator.get_animation(clip).loop = true
					animator.play(clip)
					root.set_meta("animator", animator)
				if kind == "player" and not entry.get("authored_outfit",false):
					Wardrobe.new().apply(self, root, asset_key if asset_key.begins_with("character_") else "character_well_rounded", materials)
				elif entry.has("outfit"):
					Wardrobe.new().apply_outfit(self,root,key,entry.outfit,materials,true,float(entry.scale)/1.4)
				if entry.has("art_identity"): root.set_meta("art_identity",entry.art_identity)
				root.set_meta("model_path", path)
				return root
	var prop = PropArt.new().build(self,kind,asset_key)
	if prop != null:
		root.free()
		return prop
	match kind:
		"player", "enemy", "elite":
			var hero = kind == "player"
			var skin = Color("dba477") if hero else Color("92ac70")
			var coat = Color("e99a38") if hero else Color("853f4b")
			box(root, Vector3(0, 0.62, 0), Vector3(0.46, 0.52, 0.3), coat)
			ball(root, Vector3(0, 1.09, 0), Vector3(0.55, 0.54, 0.46), skin)
			for side in [-1, 1]:
				box(root, Vector3(side * 0.14, 0.21, 0), Vector3(0.18, 0.4, 0.22), Color("243441"))
				box(root, Vector3(side * 0.14, 0.06, 0.07), Vector3(0.22, 0.12, 0.34), Color("16262e"))
				box(root, Vector3(side * 0.32, 0.65, 0.04), Vector3(0.16, 0.43, 0.2), coat)
				ball(root, Vector3(side * 0.32, 0.4, 0.1), Vector3.ONE * 0.17, skin)
				box(root, Vector3(side * 0.12, 1.12, 0.22), Vector3(0.08, 0.065, 0.045), Color("17292e") if hero else Color("efe291"))
			if hero:
				box(root, Vector3(0, 1.34, 0), Vector3(0.5, 0.1, 0.43), Color("243441"))
				box(root, Vector3(0, 0.65, 0.16), Vector3(0.33, 0.09, 0.04), Color("fff0bd"))
			if kind == "elite":
				root.scale = Vector3.ONE * 1.7
		"weapon":
			box(root, Vector3(0.18, 0, 0), Vector3(0.55, 0.16, 0.16), Color("374c57"))
			box(root, Vector3(0.04, -0.15, 0), Vector3(0.14, 0.26, 0.13), Color("a87548"))
			box(root, Vector3(0.48, 0, 0), Vector3(0.19, 0.09, 0.09), Color("b8d0cc"))
		"material":
			var gem = box(root, Vector3(0, 0.13, 0), Vector3.ONE * 0.18, Color("66e4a0"), true)
			gem.rotation_degrees = Vector3(30, 45, 20)
		"consumable":
			box(root, Vector3(0, 0.22, 0), Vector3(0.45, 0.4, 0.38), Color("e7dbb3"))
			box(root, Vector3(0, 0.43, 0), Vector3(0.3, 0.02, 0.09), Color("d65c46"))
			box(root, Vector3(0, 0.44, 0), Vector3(0.09, 0.02, 0.3), Color("d65c46"))
		"tree":
			box(root, Vector3(0, 0.2, 0), Vector3(0.65, 0.4, 0.65), Color("9a8470"))
			box(root, Vector3(0, 0.75, 0), Vector3(0.13, 1.0, 0.13), Color("625039"))
			ball(root, Vector3(0, 1.2, 0), Vector3(0.95, 1.1, 0.85), Color("466b4c"))
		"structure":
			box(root, Vector3(0, 0.18, 0), Vector3(0.75, 0.36, 0.75), Color("455b61"))
			box(root, Vector3(0, 0.55, 0), Vector3(0.44, 0.4, 0.44), Color("df9e48"))
			box(root, Vector3(0, 0.65, -0.4), Vector3(0.15, 0.15, 0.65), Color("263a43"))
		"pet":
			box(root, Vector3(0, 0.38, 0), Vector3(0.4, 0.32, 0.6), Color("cfb57b"))
			ball(root, Vector3(0, 0.6, 0.3), Vector3(0.38, 0.35, 0.35), Color("e6ce9c"))
			for side in [-1, 1]:
				box(root, Vector3(side * 0.17, 0.15, 0.2), Vector3(0.12, 0.3, 0.13), Color("8e744f"))
				box(root, Vector3(side * 0.17, 0.15, -0.2), Vector3(0.12, 0.3, 0.13), Color("8e744f"))
		"enemy_projectile":
			ball(root, Vector3.ZERO, Vector3.ONE * 0.22, Color("e57391"), true)
		"projectile":
			box(root, Vector3.ZERO, Vector3(0.32, 0.065, 0.065), Color("ffdb75"), true)
		"birth":
			ball(root, Vector3(0, 0.025, 0), Vector3(0.7, 0.04, 0.7), Color("9a454a"), true)
		"explosion":
			ball(root, Vector3(0, 0.2, 0), Vector3.ONE, Color("ff9944"), true)
	return root

func find_animator(node):
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found = find_animator(child)
		if found != null: return found
	return null

func _mesh_bounds(node, parent_transform, result):
	var current_transform = parent_transform
	if node is Spatial: current_transform = parent_transform * node.transform
	if node is MeshInstance and node.mesh != null:
		result.append(current_transform.xform(node.get_aabb()))
	for child in node.get_children(): _mesh_bounds(child, current_transform, result)

func _bio_visual(key, entry):
	var root = Spatial.new()
	root.set_meta("art_identity",key)
	root.scale = Vector3.ONE * float(entry.get("scale",1.0))
	if entry.recipe == "spore_nest":
		box(root,Vector3(0,0.08,0),Vector3(0.8,0.16,0.65),Color("536c60"))
		for i in range(5):
			var angle = i * TAU / 5
			ball(root,Vector3(cos(angle)*0.24,0.23,sin(angle)*0.22),Vector3(0.29,0.4,0.27),Color("8fa966"))
		ball(root,Vector3(0,0.27,0),Vector3(0.37,0.45,0.34),Color("bad976"))
		for side in [-1,1]: box(root,Vector3(side*0.32,0.18,0),Vector3(0.07,0.035,0.6),Color("d9a84e"))
	else:
		# Biohazard tendril breaking through a vent, with suction nodes and eyes.
		ball(root,Vector3(0,0.1,0),Vector3(0.65,0.22,0.65),Color("5d7661"))
		for i in range(8):
			var t = float(i)/7
			var center = Vector3(sin(t*1.9)*0.32,t*1.2,0)
			var size = 0.36*(1-t*0.6)
			ball(root,center,Vector3.ONE*size,Color("829b73"))
			ball(root,center+Vector3(0,0,size*0.46),Vector3.ONE*size*0.28,Color("c6d591"))
		ball(root,Vector3(0.3,1.2,0.07),Vector3(0.22,0.22,0.2),Color("a6bc7f"))
		for side in [-1,1]: ball(root,Vector3(0.3+side*0.07,1.23,0.14),Vector3.ONE*0.07,Color("e6d76c"),true)
	return root

func decorate_enemy(root, identity: String):
	# Readable combat roles remain distinct even before bespoke art is supplied.
	if "bruiser" in identity or "colossus" in identity or "rhino" in identity:
		root.scale *= 1.4
		box(root, Vector3(0, 1.36, 0), Vector3(0.65, 0.16, 0.52), Color("d8ad44"))
		for side in [-1, 1]:
			box(root, Vector3(side * 0.38, 0.87, 0), Vector3(0.25, 0.28, 0.4), Color("455665"))
	elif "spitter" in identity or "invoker" in identity:
		ball(root, Vector3(0, 0.68, -0.3), Vector3(0.4, 0.6, 0.3), Color("9fc747"), true)
		box(root, Vector3(0, 1.0, 0.2), Vector3(0.3, 0.2, 0.14), Color("45573a"))
	elif "healer" in identity or "buffer" in identity:
		box(root, Vector3(0, 1.38, 0), Vector3(0.48, 0.18, 0.4), Color("e7e8d3"))
		box(root, Vector3(0, 1.4, 0.205), Vector3(0.2, 0.06, 0.025), Color("df5a52"))
	elif "charger" in identity or "fly" in identity or "junkie" in identity:
		root.scale *= 0.82
		box(root, Vector3(0, 0.85, -0.25), Vector3(0.36, 0.48, 0.17), Color("d87e35"))
	elif "spawner" in identity or "mom" in identity:
		root.scale *= Vector3(1.4, 1.15, 1.35)
		ball(root, Vector3(0, 0.65, 0.22), Vector3(0.55, 0.55, 0.32), Color("6d915b"))

func create_weapon(identity: String, melee: bool, tier: int):
	if manifest.has(identity) and manifest[identity].has("path") and ResourceLoader.exists(manifest[identity].path):
		var imported = create("weapon", identity)
		if imported.has_meta("model_path"):
			var bounds = []
			_mesh_bounds(imported, Transform.IDENTITY, bounds)
			if bounds.size() > 0:
				var combined = bounds[0]
				for index in range(1, bounds.size()): combined = combined.merge(bounds[index])
				var entry = manifest[identity]
				var offset = entry.get("weapon_offset", [0.0, 0.0, 0.0])
				var shift = Vector3(offset[0], offset[1], offset[2]) - combined.position - combined.size * 0.5
				for child in imported.get_children():
					if child is Spatial: child.translation += shift
				if entry.has("tier_marker"):
					var marker = entry.tier_marker
					var color = [Color("d1ad76"), Color("66cc91"), Color("bb87e9"), Color("ffad42")][clamp(tier, 0, 3)]
					box(imported, Vector3(marker[0], marker[1], marker[2]), Vector3(0.1, 0.012, 0.09), color)
				imported.set_meta("weapon_tier", tier)
				return imported
		imported.free()
	var authored = WeaponArt.new().build(self, identity, tier)
	if authored != null: return authored
	var root = Spatial.new()
	var accent = [Color("b49e77"), Color("71c77e"), Color("ad81df"), Color("ed9a45")][clamp(tier, 0, 3)]
	if melee:
		box(root, Vector3.ZERO, Vector3(0.32, 0.12, 0.12), Color("875a37"))
		if "spear" in identity or "javelin" in identity or "lance" in identity:
			box(root, Vector3(0.3, 0, 0), Vector3(1.3, 0.07, 0.07), Color("a38557"))
			box(root, Vector3(1.0, 0, 0), Vector3(0.36, 0.04, 0.2), Color("c7ddd7"))
		elif "hammer" in identity or "wrench" in identity or "fist" in identity or "rock" in identity:
			box(root, Vector3(0.45, 0, 0), Vector3(0.3, 0.25, 0.5), Color("8ca4a7"))
		elif "torch" in identity or "wand" in identity:
			ball(root, Vector3(0.4, 0, 0), Vector3.ONE * 0.3, Color("ffa442"), true)
		else:
			box(root, Vector3(0.42, 0, 0), Vector3(0.55, 0.045, 0.2), Color("c7ddd7"))
			box(root, Vector3(0.12, 0, 0), Vector3(0.05, 0.1, 0.3), accent)
	else:
		box(root, Vector3(0.12, 0, 0), Vector3(0.42, 0.18, 0.18), Color("344b57"))
		box(root, Vector3(-0.05, -0.13, 0), Vector3(0.14, 0.24, 0.13), accent)
		var length = 0.6 if "sniper" in identity or "shotgun" in identity else 0.28
		box(root, Vector3(0.35 + length * 0.5, 0, 0), Vector3(length, 0.075, 0.09), Color("a3b8b6"))
		if "laser" in identity or "plasma" in identity or "taser" in identity or "nuclear" in identity:
			box(root, Vector3(0.17, 0.11, 0), Vector3(0.32, 0.06, 0.13), Color("6de5d9"), true)
		elif "launcher" in identity or "thrower" in identity:
			box(root, Vector3(0.35, 0.02, 0), Vector3(0.65, 0.25, 0.25), accent)
		elif "smg" in identity or "minigun" in identity:
			box(root, Vector3(0.17, -0.16, 0), Vector3(0.16, 0.22, 0.13), Color("657b7e"))
		if tier > 0:
			box(root, Vector3(0.12, 0.14, 0), Vector3(0.2, 0.1, 0.1), accent)
	return root
