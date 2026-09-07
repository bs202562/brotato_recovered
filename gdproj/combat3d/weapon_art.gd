extends Reference
# Authored modular hard-surface weapons. Every shipped identity has a design.
# Dimensions are in combat world units, aiming along +X.
const DESIGNS = {
	"anchor": ["anchor", 1.0], "bloody_vorpal": ["sword", 1.15],
	"blunderbuss": ["blunderbuss", 0.95], "brick": ["brick", 0.65],
	"cacti_club": ["spike_club", 0.9], "captains_sword": ["saber", 1.0],
	"chain_gun": ["rotary", 1.25], "chainsaw": ["chainsaw", 1.0],
	"chopper": ["cleaver", 0.85], "circular_saw": ["saw", 0.9],
	"claw": ["claw", 0.7], "crossbow": ["crossbow", 1.0],
	"dagger": ["knife", 0.65], "dextroyer": ["rotary", 1.4],
	"double_barrel_shotgun": ["shotgun", 1.0], "drill": ["drill", 0.9],
	"excalibur": ["sword", 1.3], "fighting_stick": ["staff", 1.0],
	"fireball": ["orb", 0.75], "fist": ["glove", 0.7],
	"flamethrower": ["flamer", 1.1], "flaming_brass_knuckles": ["knuckles", 0.75],
	"flute": ["flute", 0.85], "gatling_laser": ["rotary", 1.1],
	"ghost_axe": ["axe", 0.9], "ghost_flint": ["knife", 0.8],
	"ghost_scepter": ["scepter", 1.0], "grenade_launcher": ["launcher", 0.95],
	"hammer": ["hammer", 0.9], "hand": ["glove", 0.85],
	"harpoon_gun": ["harpoon", 1.1], "hatchet": ["axe", 0.7],
	"hiking_stick": ["staff", 1.1], "icicle": ["crystal", 0.8],
	"javelin": ["spear", 1.0], "jousting_lance": ["lance", 1.2],
	"knife": ["knife", 0.8], "laser_gun": ["energy", 0.9],
	"lightning_shiv": ["knife", 0.7], "lute": ["lute", 1.0],
	"mace": ["spike_club", 1.0], "medical_gun": ["medical", 0.85],
	"minigun": ["rotary", 1.0], "nuclear_launcher": ["launcher", 1.3],
	"obliterator": ["energy", 1.25], "particle_accelerator": ["rail", 1.2],
	"pistol": ["pistol", 0.8], "plank": ["plank", 0.9],
	"plasma_sledgehammer": ["hammer", 1.2], "potato_thrower": ["scrap_launcher", 1.0],
	"power_fist": ["glove", 1.0], "pruner": ["shears", 0.9],
	"rail_gun": ["rail", 1.05], "revolver": ["revolver", 0.85],
	"rock": ["rock", 0.7], "rocket_launcher": ["launcher", 1.15],
	"scissors": ["shears", 0.75], "screwdriver": ["screwdriver", 0.75],
	"scythe": ["scythe", 1.2], "sharp_tooth": ["tooth", 0.7],
	"shredder": ["smg", 1.15], "shuriken": ["star", 0.8],
	"sickle": ["sickle", 0.9], "slingshot": ["slingshot", 0.8],
	"smg": ["smg", 0.85], "sniper_gun": ["sniper", 1.2],
	"spear": ["spear", 1.1], "spiky_shield": ["shield", 1.0],
	"spoon": ["spoon", 0.8], "stick": ["staff", 0.8],
	"sword": ["sword", 1.0], "taser": ["taser", 0.7],
	"thunder_sword": ["sword", 1.1], "torch": ["torch", 0.9],
	"trident": ["trident", 1.15], "wand": ["scepter", 0.8],
	"war_hammer": ["hammer", 1.15], "wrench": ["wrench", 0.9]
}
var f
var metal = Color("a6c1c5")
var dark = Color("233642")
var grip = Color("9a6845")
var accent = Color("e9ae54")
var glow = false

func build(factory, identity: String, tier: int):
	f = factory
	var key = identity.trim_prefix("weapon_")
	if not DESIGNS.has(key): return null
	var root = Spatial.new()
	root.set_meta("art_identity", identity)
	var design = DESIGNS[key]
	root.scale = Vector3.ONE * design[1]
	accent = [Color("d1ad76"), Color("66cc91"), Color("bb87e9"), Color("ffad42")][clamp(tier, 0, 3)]
	metal = Color("adc4c8")
	glow = false
	if "ghost" in key or "lightning" in key or "thunder" in key or "plasma" in key or key in ["icicle", "laser_gun", "gatling_laser", "particle_accelerator"]:
		metal = Color("63d9e0")
		glow = true
	if key == "bloody_vorpal": metal = Color("bf5664")
	if key == "excalibur": metal = Color("e4cd8b")
	match design[0]:
		"pistol", "smg", "sniper", "shotgun", "revolver", "energy", "rail", "medical", "taser", "blunderbuss", "harpoon", "flamer", "launcher", "scrap_launcher", "rotary":
			gun(root, design[0], key)
		"knife", "sword", "saber", "cleaver", "axe", "hammer", "staff", "spear", "lance", "trident", "scythe", "sickle", "spike_club", "scepter", "torch", "anchor", "wrench", "screwdriver", "spoon", "flute":
			tool(root, design[0], key)
		"chainsaw", "saw", "drill":
			power_tool(root, design[0])
		"glove", "knuckles", "claw", "shield":
			armor(root, design[0], key)
		"crossbow", "slingshot", "shears", "lute":
			special(root, design[0])
		"brick":
			f.box(root, Vector3(0.25,0,0), Vector3(0.65,0.27,0.37), Color("b87859"))
			for x in [0.07,0.27,0.47]: f.box(root,Vector3(x,0.14,0),Vector3(0.08,0.01,0.14),dark)
		"plank":
			f.box(root,Vector3(0.3,0,0),Vector3(1.05,0.1,0.27),grip)
			for x in [0.05,0.55]: rod(root,Vector3(x,-0.03,-0.06),Vector3(x,0.19,-0.06),0.025,metal)
		"rock":
			f.ball(root,Vector3(0.22,0,0),Vector3(0.7,0.4,0.55),Color("89938c"))
			f.box(root,Vector3(0.15,0.18,0),Vector3(0.28,0.025,0.4),accent)
		"tooth", "crystal":
			cone(root,Vector3(0.2,0,0),Vector3(0.8,0,0),0.2,metal if glow else Color("e2dcc1"))
		"orb":
			f.ball(root,Vector3(0.2,0,0),Vector3.ONE*0.44,Color("ffb33e"),true)
			for i in range(5): cone(root,Vector3(0.14,0,0),Vector3(-0.2,0.2*sin(i*TAU/5),0.2*cos(i*TAU/5)),0.1,Color("ee6b35"))
		"star":
			for i in range(4):
				var blade = f.box(root,Vector3(0.22,0,0),Vector3(0.7,0.04,0.13),metal)
				blade.rotation.y = i*PI/4
			f.ball(root,Vector3(0.22,0.025,0),Vector3(0.16,0.08,0.16),accent)
	return root

func rod(root, start, end, radius, color, luminous=false):
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 10
	mesh.rings = 1
	var part = f.part(root,mesh,(start+end)*0.5,color,luminous)
	var axis = (end-start).normalized()
	var tangent = Vector3.FORWARD if abs(axis.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	part.transform.basis = Basis(axis.cross(tangent).normalized(),axis,axis.cross(tangent).normalized().cross(axis))
	return part

func cone(root, start, end, radius, color):
	var result = rod(root,start,end,radius,color,glow)
	result.mesh.top_radius = 0.0
	return result

func handle(root, length=0.4):
	rod(root,Vector3(-0.15,0,0),Vector3(length,0,0),0.06,grip)
	for x in [-0.1,0.0,0.1]: rod(root,Vector3(x-0.012,0,0),Vector3(x+0.012,0,0),0.065,dark)

func blade(root, start, end, width):
	# Faceted taper with a raised central ridge, rather than a flat rectangle.
	var mesh = PrismMesh.new()
	mesh.size = Vector3(end-start,0.055,width)
	var part = f.part(root,mesh,Vector3((start+end)/2,0,0),metal,glow)
	part.rotation_degrees.x = 90
	return part

func tool(root, shape, key):
	var long_shaft = shape in ["staff","spear","lance","trident","scythe","anchor"]
	handle(root,1.0 if long_shaft else 0.48)
	match shape:
		"knife", "sword", "saber":
			blade(root,0.2,1.1 if shape != "knife" else 0.7,0.19 if shape != "knife" else 0.14)
			f.box(root,Vector3(0.2,0,0),Vector3(0.075,0.1,0.4),accent)
			if shape == "saber": rod(root,Vector3(-0.12,0,0.08),Vector3(0.2,0,0.23),0.035,accent)
		"cleaver":
			f.box(root,Vector3(0.55,0,0),Vector3(0.55,0.055,0.42),metal)
			rod(root,Vector3(0.3,0.015,-0.2),Vector3(0.8,0.015,-0.2),0.025,Color("e2e9df"))
		"axe":
			f.box(root,Vector3(0.5,0,0.06),Vector3(0.35,0.1,0.5),metal,glow)
			blade(root,0.37,0.72,0.56)
		"hammer":
			f.box(root,Vector3(0.55,0,0),Vector3(0.35,0.3,0.6),dark)
			for side in [-1,1]: f.box(root,Vector3(0.55,0,side*0.31),Vector3(0.37,0.32,0.08),metal,glow)
			f.box(root,Vector3(0.55,0.16,0),Vector3(0.22,0.03,0.26),accent)
		"staff":
			rod(root,Vector3(0.85,0,0),Vector3(1.05,0,0),0.08,accent)
			if key == "hiking_stick": rod(root,Vector3(0.98,0,0),Vector3(1.07,0,0.2),0.07,grip)
		"spear", "lance", "trident":
			cone(root,Vector3(0.88,0,0),Vector3(1.38,0,0),0.12 if shape != "lance" else 0.19,metal)
			if shape == "lance": rod(root,Vector3(0.05,0,0),Vector3(0.09,0,0),0.2,accent)
			if shape == "trident":
				rod(root,Vector3(0.9,0,-0.23),Vector3(0.9,0,0.23),0.045,accent)
				for side in [-1,1]: cone(root,Vector3(0.9,0,side*0.23),Vector3(1.3,0,side*0.23),0.07,metal)
		"scythe", "sickle":
			var end = 1.0 if shape == "scythe" else 0.5
			for i in range(5):
				var theta = float(i)/4 * 1.5
				var p = f.box(root,Vector3(end+sin(theta)*0.2,0,cos(theta)*0.55-0.1),Vector3(0.17,0.04,0.24-i*0.035),metal)
				p.rotation.y = theta
		"spike_club":
			rod(root,Vector3(0.35,0,0),Vector3(0.8,0,0),0.17,Color("678b5b") if key == "cacti_club" else dark)
			for i in range(8):
				var radial = Vector3(0,sin(i*TAU/8),cos(i*TAU/8))
				cone(root,Vector3(0.55,0,0)+radial*0.13,Vector3(0.55,0,0)+radial*0.29,0.055,metal)
		"scepter", "torch":
			# Torch is wrapped physical material; its live flame is emitter-driven.
			f.ball(root,Vector3(0.6,0,0),Vector3.ONE*0.29,Color("b59b73") if shape == "torch" else Color("70dacf"),shape!="torch")
			for side in [-1,1]: rod(root,Vector3(0.38,0,side*0.05),Vector3(0.61,0,side*0.19),0.035,accent)
		"anchor":
			rod(root,Vector3(0.8,0,-0.42),Vector3(0.8,0,0.42),0.07,metal)
			for side in [-1,1]: cone(root,Vector3(0.8,0,side*0.42),Vector3(0.48,0,side*0.5),0.11,metal)
		"wrench":
			for side in [-1,1]: f.box(root,Vector3(0.58,0,side*0.14),Vector3(0.32,0.12,0.1),metal)
			f.box(root,Vector3(0.43,0,0),Vector3(0.16,0.12,0.34),metal)
		"screwdriver":
			rod(root,Vector3(-0.15,0,0),Vector3(0.2,0,0),0.1,accent)
			rod(root,Vector3(0.2,0,0),Vector3(0.68,0,0),0.027,metal)
			f.box(root,Vector3(0.72,0,0),Vector3(0.1,0.023,0.09),metal)
		"spoon": f.ball(root,Vector3(0.65,0,0),Vector3(0.33,0.07,0.24),metal)
		"flute":
			rod(root,Vector3(-0.15,0,0),Vector3(0.8,0,0),0.065,metal)
			for i in range(5): f.ball(root,Vector3(i*0.12,0.06,0),Vector3(0.035,0.01,0.035),dark)

func gun(root, shape, key):
	f.box(root,Vector3(0.1,0,0),Vector3(0.46,0.19,0.2),dark)
	var pistol_grip = f.box(root,Vector3(-0.04,-0.15,0),Vector3(0.13,0.24,0.14),grip)
	pistol_grip.rotation.z = -0.15
	f.box(root,Vector3(0.02,0.115,0),Vector3(0.24,0.035,0.17),accent)
	var length = 0.9 if shape in ["sniper","rail","harpoon"] else 0.56
	if shape == "pistol": length = 0.42
	rod(root,Vector3(0.25,0,0),Vector3(length,0,0),0.045,metal,glow)
	rod(root,Vector3(length-0.035,0,0),Vector3(length+0.015,0,0),0.067,dark)
	match shape:
		"smg", "sniper", "shotgun", "flamer", "harpoon", "rail":
			f.box(root,Vector3(-0.3,-0.025,0),Vector3(0.28,0.17,0.14),grip)
			f.box(root,Vector3(0.22,-0.16,0),Vector3(0.14,0.27,0.15),accent)
	if shape == "sniper":
		rod(root,Vector3(0.04,0.22,0),Vector3(0.41,0.22,0),0.065,dark)
		rod(root,Vector3(0.38,0.22,0),Vector3(0.42,0.22,0),0.058,Color("65bbc7"),true)
	elif shape == "shotgun":
		for side in [-1,1]: rod(root,Vector3(0.25,0,side*0.055),Vector3(0.86,0,side*0.055),0.047,metal)
		f.box(root,Vector3(0.48,-0.055,0),Vector3(0.32,0.1,0.19),grip)
	elif shape == "revolver":
		rod(root,Vector3(0.07,0,0),Vector3(0.31,0,0),0.14,metal)
		for i in range(6): rod(root,Vector3(0.09,sin(i*TAU/6)*0.12,cos(i*TAU/6)*0.12),Vector3(0.28,sin(i*TAU/6)*0.12,cos(i*TAU/6)*0.12),0.024,dark)
	elif shape in ["energy","rail","taser"]:
		for side in [-1,1]:
			f.box(root,Vector3(0.48,0,side*0.1),Vector3(0.62,0.09,0.07),metal,glow)
			f.box(root,Vector3(0.28,0.05,side*0.13),Vector3(0.2,0.1,0.02),Color("61e2d7"),true)
	elif shape in ["launcher","scrap_launcher","blunderbuss"]:
		rod(root,Vector3(-0.1,0.04,0),Vector3(0.7,0.04,0),0.17,accent)
		rod(root,Vector3(0.65,0.04,0),Vector3(0.73,0.04,0),0.19,dark)
		rod(root,Vector3(0.731,0.04,0),Vector3(0.735,0.04,0),0.13,Color("111c25"))
		if key == "nuclear_launcher":
			for i in range(3): f.box(root,Vector3(i*0.18,0.22,0),Vector3(0.08,0.07,0.25),Color("93de58"),true)
	elif shape == "rotary":
		for i in range(6):
			var offset = Vector3(0,sin(i*TAU/6)*0.105,cos(i*TAU/6)*0.105)
			rod(root,Vector3(0.22,0,0)+offset,Vector3(0.83,0,0)+offset,0.037,metal,glow)
		for x in [0.34,0.7]: rod(root,Vector3(x,0,0),Vector3(x+0.055,0,0),0.155,dark)
		rod(root,Vector3(0.06,-0.19,-0.19),Vector3(0.06,-0.19,0.19),0.16,accent)
	elif shape == "medical":
		rod(root,Vector3(0.2,0.17,0),Vector3(0.52,0.17,0),0.1,Color("dae9df"))
		f.box(root,Vector3(0.29,0.27,0),Vector3(0.16,0.015,0.06),Color("e66c59"))
		f.box(root,Vector3(0.29,0.28,0),Vector3(0.055,0.015,0.16),Color("e66c59"))
	elif shape == "flamer":
		rod(root,Vector3(0.16,-0.16,0),Vector3(0.48,-0.16,0),0.115,Color("bb5743"))
		cone(root,Vector3(0.57,0,0),Vector3(0.74,0,0),0.07,Color("ffad42"))
	elif shape == "harpoon": cone(root,Vector3(0.62,0,0),Vector3(1.0,0,0),0.08,metal)

func power_tool(root, shape):
	f.box(root,Vector3(0.03,0,0),Vector3(0.38,0.27,0.3),accent)
	f.box(root,Vector3(-0.19,0,0),Vector3(0.09,0.2,0.34),dark)
	if shape == "chainsaw":
		f.box(root,Vector3(0.54,0,0),Vector3(0.75,0.055,0.24),metal)
		for i in range(9):
			for side in [-1,1]: f.box(root,Vector3(0.22+i*0.075,0,side*0.14),Vector3(0.045,0.075,0.07),dark)
	elif shape == "saw":
		rod(root,Vector3(0.4,-0.025,0),Vector3(0.4,0.025,0),0.34,metal)
		for i in range(14):
			var point = Vector3(cos(i*TAU/14),0,sin(i*TAU/14))
			cone(root,Vector3(0.4,0,0)+point*0.29,Vector3(0.4,0,0)+point*0.39,0.055,metal)
		rod(root,Vector3(0.4,0.02,0),Vector3(0.4,0.06,0),0.07,dark)
	else:
		cone(root,Vector3(0.2,0,0),Vector3(0.95,0,0),0.18,metal)
		for i in range(6): rod(root,Vector3(0.25+i*0.09,0,0),Vector3(0.28+i*0.09,0,0),0.17-i*0.022,dark)

func armor(root, shape, key):
	if shape == "shield":
		f.ball(root,Vector3(0.2,0,0),Vector3(0.85,0.22,0.7),dark)
		for i in range(5):
			var a = i*TAU/5
			cone(root,Vector3(0.2+cos(a)*0.25,0.04,sin(a)*0.22),Vector3(0.2+cos(a)*0.25,0.3,sin(a)*0.22),0.065,metal)
		f.box(root,Vector3(0.2,0.115,0),Vector3(0.1,0.025,0.6),accent)
	else:
		f.ball(root,Vector3(0.24,0,0),Vector3(0.5,0.27,0.42),Color("b95745") if key == "fist" else accent)
		f.box(root,Vector3(-0.03,0,0),Vector3(0.18,0.25,0.34),dark)
		for i in range(4):
			f.box(root,Vector3(0.37,0.07,(i-1.5)*0.09),Vector3(0.19,0.17,0.08),metal if shape != "glove" else accent)
			if shape == "claw": cone(root,Vector3(0.43,0.08,(i-1.5)*0.09),Vector3(0.8,0.08,(i-1.5)*0.1),0.045,metal)
		if key == "flaming_brass_knuckles": f.ball(root,Vector3(0.36,0.18,0),Vector3(0.35,0.15,0.3),Color("ffa747"),true)

func special(root, shape):
	if shape in ["crossbow","slingshot"]:
		handle(root,0.5)
		for side in [-1,1]:
			rod(root,Vector3(0.37,0,0),Vector3(0.2,0,side*0.42),0.055,metal)
			rod(root,Vector3(0.2,0,side*0.42),Vector3(-0.06,0,0),0.014,Color("cfbd8f"))
		if shape == "crossbow": cone(root,Vector3(0.45,0.04,0),Vector3(0.78,0.04,0),0.045,metal)
	elif shape == "shears":
		for side in [-1,1]:
			f.ball(root,Vector3(-0.05,0,side*0.16),Vector3(0.25,0.065,0.2),accent)
			var part = f.box(root,Vector3(0.34,0,side*0.08),Vector3(0.63,0.035,0.08),metal)
			part.rotation.y = side*0.25
		f.ball(root,Vector3(0.15,0.04,0),Vector3.ONE*0.075,dark)
	elif shape == "lute":
		f.ball(root,Vector3(0.5,0,0),Vector3(0.58,0.16,0.4),grip)
		f.box(root,Vector3(0.03,0,0),Vector3(0.55,0.07,0.1),dark)
		for i in range(4): rod(root,Vector3(-0.2,0.08,(i-1.5)*0.017),Vector3(0.62,0.08,(i-1.5)*0.017),0.003,metal)
