extends Reference
# Explicit outfits for the complete base + DLC roster. Shared skeletons permit
# consistent animation; garments and silhouettes identify the selected role.
const PALETTE = preload("res://combat3d/survivor_palette.shader")
const OUTFITS = {
	"well_rounded": ["cap","radio","e39c42","dba77e"],
	"buccaneer": ["tricorn","pouches","a8574f","bd8a63"],
	"builder": ["hardhat","toolbox","d4a342","e2b78d"],
	"captain": ["sailor","cape","395c85","b98763"],
	"chef": ["chef","pouches","e4dcca","d8a680"],
	"creature": ["antlers","tanks","75916b","9eb879"],
	"curious": ["goggles","book","c99765","dfb38b"],
	"diver": ["visor","tanks","d0a233","bb886a"],
	"druid": ["antlers","cape","579576","d0a47b"],
	"dwarf": ["helmet","toolbox","91634b","d9a57c"],
	"gangster": ["fedora","chain","554e71","b77d58"],
	"hiker": ["beanie","backpack","ad744b","e3b58a"],
	"ogre": ["mohawk","shield","8d7760","9aa774"],
	"romantic": ["beret","scarf","c67586","d5a180"],
	"sailor": ["sailor","radio","d0dfdf","a87b5f"],
	"apprentice": ["beanie","book","9381bc","e0ba96"],
	"arms_dealer": ["fedora","pouches","a48359","c5916c"],
	"artificer": ["goggles","tanks","ba6c3f","ce9e7d"],
	"baby": ["beanie","scarf","b5cad1","e2b394"],
	"beast_master": ["bandana","backpack","977859","ab7d5f"],
	"brawler": ["bandana","chain","b84945","b38366"],
	"bull": ["horns","shield","9d593e","c79776"],
	"chunky": ["beanie","pouches","b17f49","d8ab83"],
	"crazy": ["mohawk","chain","a766a0","c69873"],
	"cryptid": ["antlers","backpack","5b735b","b2b387"],
	"cyborg": ["visor","antenna","829d9e","adb4a9"],
	"demon": ["horns","cape","ac5862","c48272"],
	"doctor": ["medical","medbag","e0e6d4","c79473"],
	"engineer": ["hardhat","toolbox","d89b35","cb9c72"],
	"entrepreneur": ["fedora","radio","8a6e55","a87e64"],
	"explorer": ["straw","backpack","8b985d","c49368"],
	"farmer": ["straw","pouches","8fa26e","ad8060"],
	"fisherman": ["beanie","tanks","719dad","c09879"],
	"generalist": ["cap","pouches","789c97","dfb38d"],
	"ghost": ["hood","cape","b8d8d1","bbd0c9"],
	"gladiator": ["helmet","shield","b48647","bd8862"],
	"glutton": ["chef","medbag","b98a70","dbab86"],
	"golem": ["helmet","antenna","788b87","acb5a6"],
	"hunter": ["hood","quiver","68836d","c89b78"],
	"jack": ["fedora","chain","b5a04d","c79776"],
	"king": ["crown","cape","946780","dcb28d"],
	"knight": ["helmet","cape","8b9cab","c49270"],
	"lich": ["crown","book","8f81bb","b8c4a3"],
	"loud": ["headphones","radio","d38b49","c59a7b"],
	"lucky": ["beret","pouches","6bb496","d4a483"],
	"mage": ["wizard","book","9071b0","c39777"],
	"masochist": ["bandana","shield","965f65","c79675"],
	"multitasker": ["goggles","toolbox","8e9e57","bd8e6e"],
	"mutant": ["mohawk","tanks","7c9650","abb68b"],
	"old": ["fedora","scarf","948575","d0ae8c"],
	"one_arm": ["beret","radio","536e85","b58e70"],
	"pacifist": ["beret","medbag","d6cfaa","d1a280"],
	"ranger": ["hood","quiver","748b58","ce9d75"],
	"renegade": ["bandana","pouches","a76a51","a67c5b"],
	"saver": ["cap","backpack","aa995f","d2a888"],
	"sick": ["medical","scarf","a5bfac","b9b492"],
	"soldier": ["helmet","pouches","6d8568","ab7c5f"],
	"speedy": ["headphones","scarf","c18b4f","ce9a72"],
	"streamer": ["headphones","antenna","9b77b5","d2a384"],
	"technomage": ["visor","book","599aaf","b89b80"],
	"vagabond": ["hood","backpack","9e866a","bb916f"],
	"vampire": ["top_hat","cape","99566e","d4b6a9"],
	"wildling": ["mohawk","quiver","8f7451","a77b5d"],
	"wounded": ["medical","shield","9f796a","c4987a"]
}

func apply(factory, root, identity, material_cache):
	var key = identity.trim_prefix("character_")
	if not OUTFITS.has(key): return
	var outfit = OUTFITS[key]
	apply_outfit(factory,root,identity,outfit,material_cache)

func apply_outfit(factory,root,identity,outfit,material_cache,zombie=false,size=1.0):
	var key = identity
	var coat = Color(outfit[2])
	var skin = Color(outfit[3])
	recolor(root,key,coat,skin,material_cache,zombie)
	var head = Spatial.new()
	head.scale = Vector3.ONE * size
	root.add_child(head)
	var back = Spatial.new()
	back.scale = Vector3.ONE * size
	root.add_child(back)
	var metal = Color("79999e")
	var dark = Color("243844")
	var front = -0.21
	match outfit[0]:
		"cap", "sailor", "medical", "beret", "beanie", "hardhat", "helmet", "fedora", "top_hat", "straw", "chef":
			var hat_color = coat
			if outfit[0] in ["sailor","medical","chef"]: hat_color = Color("e2e7d6")
			if outfit[0] == "helmet": hat_color = metal
			var brim = Vector3(0.58,0.055,0.5)
			if outfit[0] in ["straw","fedora"]: brim = Vector3(0.76,0.05,0.66)
			factory.box(head,Vector3(0,1.38,0),brim,hat_color)
			factory.ball(head,Vector3(0,1.45,0.02),Vector3(0.5,0.22,0.43),hat_color)
			if outfit[0] == "top_hat": factory.box(head,Vector3(0,1.59,0.02),Vector3(0.4,0.4,0.37),dark)
			if outfit[0] == "chef":
				factory.box(head,Vector3(0,1.53,0),Vector3(0.4,0.3,0.36),hat_color)
				for x in [-0.15,0,0.15]: factory.ball(head,Vector3(x,1.7,0),Vector3(0.27,0.22,0.4),hat_color)
			if outfit[0] == "medical":
				factory.box(head,Vector3(0,1.46,front-0.01),Vector3(0.18,0.05,0.035),Color("dd6959"))
				factory.box(head,Vector3(0,1.46,front-0.02),Vector3(0.05,0.15,0.035),Color("dd6959"))
			if outfit[0] == "hardhat": factory.box(head,Vector3(0,1.56,0),Vector3(0.075,0.06,0.43),Color("ebcb69"))
			if outfit[0] == "helmet":
				for side in [-1,1]: factory.box(head,Vector3(side*0.24,1.31,0.05),Vector3(0.07,0.24,0.33),metal)
		"hood", "wizard":
			factory.ball(head,Vector3(0,1.29,0.08),Vector3(0.62,0.55,0.47),coat)
			# Open front leaves the animated face unobscured.
			for side in [-1,1]: factory.box(head,Vector3(side*0.25,1.19,-0.06),Vector3(0.1,0.45,0.28),coat)
			if outfit[0] == "wizard":
				var mesh = CylinderMesh.new()
				mesh.top_radius = 0.015
				mesh.bottom_radius = 0.3
				mesh.height = 0.65
				mesh.radial_segments = 10
				factory.part(head,mesh,Vector3(0,1.65,0),coat)
		"crown", "horns", "antlers":
			factory.box(head,Vector3(0,1.4,0),Vector3(0.52,0.12,0.44),Color("d4b065") if outfit[0] == "crown" else coat)
			for side in [-1,1]:
				var horn = factory.box(head,Vector3(side*0.3,1.59,0),Vector3(0.085,0.35,0.085),Color("d4b065") if outfit[0] == "crown" else Color("c4b493"))
				horn.rotation.z = side*-0.35
				if outfit[0] == "antlers": factory.box(head,Vector3(side*0.39,1.65,0.04),Vector3(0.24,0.06,0.08),Color("af9874"))
			if outfit[0] == "crown": factory.box(head,Vector3(0,1.52,front),Vector3(0.08,0.2,0.08),Color("d4b065"))
		"headphones", "goggles", "visor":
			for side in [-1,1]: factory.box(head,Vector3(side*0.27,1.2,0),Vector3(0.12,0.22,0.19),dark)
			if outfit[0] == "headphones":
				factory.box(head,Vector3(0,1.44,0.025),Vector3(0.56,0.06,0.11),metal)
			else:
				for side in [-1,1]: factory.box(head,Vector3(side*0.12,1.24,front-0.015),Vector3(0.18,0.14,0.065),Color("73d3db"),true)
		"bandana":
			factory.box(head,Vector3(0,1.29,0.01),Vector3(0.53,0.1,0.45),coat)
			factory.box(head,Vector3(0.28,1.25,0.18),Vector3(0.15,0.08,0.2),coat)
		"mohawk":
			for z in [-0.15,0,0.15]: factory.box(head,Vector3(0,1.52,z),Vector3(0.13,0.3,0.12),coat)
		"tricorn":
			factory.box(head,Vector3(0,1.42,0),Vector3(0.73,0.07,0.58),dark)
			factory.box(head,Vector3(0,1.52,0),Vector3(0.5,0.18,0.42),dark)
			factory.box(head,Vector3(0,1.53,-0.23),Vector3(0.12,0.12,0.025),Color("e7d7ac"))
	match outfit[1]:
		"backpack", "toolbox", "medbag", "book", "radio", "pouches":
			factory.box(back,Vector3(0,0.76,0.27),Vector3(0.42,0.51,0.2),coat)
			factory.box(back,Vector3(0,1.04,0.26),Vector3(0.26,0.07,0.09),dark)
			for side in [-1,1]: factory.box(back,Vector3(side*0.16,0.78,0.385),Vector3(0.055,0.45,0.025),metal)
			if outfit[1] == "medbag":
				factory.box(back,Vector3(0,0.76,0.39),Vector3(0.25,0.06,0.03),Color("e7d9c1"))
				factory.box(back,Vector3(0,0.76,0.395),Vector3(0.06,0.25,0.03),Color("e7d9c1"))
			if outfit[1] == "toolbox":
				for side in [-1,1]: factory.box(back,Vector3(side*0.16,1.08,0.29),Vector3(0.09,0.33,0.08),metal)
			if outfit[1] == "radio": factory.box(back,Vector3(0.17,1.13,0.28),Vector3(0.025,0.55,0.025),metal)
			if outfit[1] == "book": factory.box(back,Vector3(0.3,0.54,0),Vector3(0.09,0.32,0.27),Color("d4c9a0"))
		"tanks":
			for side in [-1,1]: factory.ball(back,Vector3(side*0.14,0.79,0.31),Vector3(0.22,0.62,0.25),coat)
			factory.box(back,Vector3(0,0.81,0.45),Vector3(0.5,0.075,0.04),metal)
		"cape":
			var cape = factory.box(back,Vector3(0,0.69,0.26),Vector3(0.58,0.79,0.055),coat.darkened(0.2))
			cape.rotation.x = 0.18
			factory.box(back,Vector3(0,1.0,-0.17),Vector3(0.5,0.08,0.04),coat)
		"quiver":
			factory.box(back,Vector3(0.17,0.82,0.28),Vector3(0.24,0.64,0.2),Color("765e45"))
			for side in [-1,0,1]:
				factory.box(back,Vector3(0.17+side*0.06,1.18,0.28),Vector3(0.02,0.4,0.02),metal)
				factory.box(back,Vector3(0.17+side*0.06,1.38,0.28),Vector3(0.035,0.08,0.09),coat)
		"shield": factory.box(back,Vector3(0,0.8,0.3),Vector3(0.57,0.68,0.09),metal)
		"scarf":
			factory.box(back,Vector3(0,0.99,-0.06),Vector3(0.47,0.13,0.4),coat)
			factory.box(back,Vector3(0.13,0.8,-0.23),Vector3(0.15,0.37,0.04),coat)
		"chain":
			for x in [-0.16,-0.08,0,0.08,0.16]: factory.ball(back,Vector3(x,0.91-0.12*(1-abs(x)/0.16),-0.19),Vector3.ONE*0.06,Color("d2b679"))
		"antenna":
			factory.box(back,Vector3(0,0.8,0.3),Vector3(0.4,0.45,0.18),dark)
			factory.box(back,Vector3(0.18,1.2,0.32),Vector3(0.03,0.55,0.03),metal)
			factory.ball(back,Vector3(0.18,1.49,0.32),Vector3.ONE*0.08,Color("6edfd2"),true)
	# The shopper faces +Z; the survivor's authored wardrobe faces -Z.
	if zombie:
		head.rotation.y = PI
		back.rotation.y = PI
	bind_to_bone(root,head,"Head")
	bind_to_bone(root,back,"Spine02")
	root.set_meta("art_identity",identity)

func recolor(node,key,coat,skin,cache,zombie=false):
	if node is MeshInstance:
		for i in range(node.mesh.get_surface_count()):
			var original = node.get_surface_material(i)
			if original == null: original = node.mesh.surface_get_material(i)
			if original is SpatialMaterial and original.albedo_texture != null:
				var material_key = key + str(original.get_instance_id())
				if not cache.has(material_key):
					var material = ShaderMaterial.new()
					material.shader = PALETTE
					material.set_shader_param("source_albedo",original.albedo_texture)
					material.set_shader_param("coat_color",coat)
					material.set_shader_param("skin_color",skin)
					material.set_shader_param("zombie_palette",zombie)
					cache[material_key] = material
				node.set_surface_material(i,cache[material_key])
	for child in node.get_children(): recolor(child,key,coat,skin,cache,zombie)

func skeleton_in(node):
	if node is Skeleton: return node
	for child in node.get_children():
		var found = skeleton_in(child)
		if found != null: return found
	return null

func bind_to_bone(root,props,bone_name):
	var skeleton = skeleton_in(root)
	if skeleton == null: return
	var bone = skeleton.find_bone(bone_name)
	if bone < 0: return
	var relative = Transform.IDENTITY
	var current = skeleton
	while current != root:
		if current is Spatial: relative = current.transform * relative
		current = current.get_parent()
	var attachment = BoneAttachment.new()
	attachment.bone_name = bone_name
	skeleton.add_child(attachment)
	root.remove_child(props)
	attachment.add_child(props)
	props.transform = (relative * skeleton.get_bone_global_pose(bone)).affine_inverse() * props.transform
