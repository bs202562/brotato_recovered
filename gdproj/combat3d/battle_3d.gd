extends Node
# 3D presentation for the existing deterministic planar combat simulation.
# One world unit = 64 gameplay pixels. The Z stretch cancels camera tilt so
# mouse aim, 2D collisions and world-space HUD stay aligned with the ground.
const Factory = preload("res://combat3d/visual_factory.gd")
const ObservedStateArt = preload("res://combat3d/observed_state_art.gd")
var observed_state_art = ObservedStateArt.new()
const StatusFxArt = preload("res://combat3d/status_fx_art.gd")
const PlayerLocatorArt = preload("res://combat3d/player_locator_art.gd")
const PetStatusArt = preload("res://combat3d/pet_status_art.gd")
var pet_status_art=PetStatusArt.new()
const PetActionArt = preload("res://combat3d/pet_action_art.gd")
var pet_action_art=PetActionArt.new()
const CatlingAimArt = preload("res://combat3d/catling_aim_art.gd")
var catling_aim_art=CatlingAimArt.new()
const BirthStatusArt = preload("res://combat3d/birth_status_art.gd")
var birth_status_art=BirthStatusArt.new()
const TorchFlameArt = preload("res://combat3d/torch_flame_art.gd")
var torch_flame_art=TorchFlameArt.new()
var status_fx_art = StatusFxArt.new()
var healing_visual_frames = {}
const BurnArt = preload("res://combat3d/burn_art.gd")
const PIXELS = 64.0
const TILT = 0.872664626
const SOURCES = ["Entities", "Materials", "Consumables", "Births", "PlayerProjectiles", "EnemyProjectiles", "Explosions"]
var factory = Factory.new()
var main
var viewport
var world
var camera
var canvas
var screen
var proxies = {}
var effects = []
var elapsed = 0.0
var enabled = true
var original_modulates = {}
var visual_rng = RandomNumberGenerator.new()

func _ready():
	visual_rng.randomize()
	main = get_parent()
	canvas = CanvasLayer.new()
	canvas.layer = -5
	add_child(canvas)
	viewport = Viewport.new()
	viewport.own_world = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	viewport.msaa = Viewport.MSAA_2X
	viewport.hdr = false
	viewport.render_target_v_flip = true
	viewport.shadow_atlas_size = 2048
	add_child(viewport)
	world = Spatial.new()
	viewport.add_child(world)
	screen = TextureRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.expand = true
	screen.texture = viewport.get_texture()
	canvas.add_child(screen)
	camera = Camera.new()
	camera.projection = Camera.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 150.0
	world.add_child(camera)
	camera.current = true
	_build_arena()
	for path in SOURCES + ["TileMap", "Effects"]:
		var node = main.get_node_or_null(path)
		if node is CanvasItem:
			original_modulates[node] = node.modulate
			node.modulate.a = 0.0
	# Observe future spawns without rescanning the whole tree every frame.
	get_tree().connect("node_added", self, "_node_added")
	_scan(main)
	RunData.connect("healing_effect", self, "_on_healing")
	RunData.connect("lifesteal_effect", self, "_on_healing")
	RunData.connect("levelled_up", self, "_on_level_up")
	set_process_input(true)
	print("COMBAT3D: real 3D renderer attached")

func _node_added(node):
	if node is Node2D and main.is_a_parent_of(node):
		call_deferred("_register", node)

func _scan(node):
	_register(node)
	for child in node.get_children():
		if child != self:
			_scan(child)

func _kind(node):
	if node is Jellyshield: return "pet"
	if node is Weapon:
		return "weapon"
	if node is GroupOfBullet: return ""
	if node is EnemyProjectile: return "enemy_projectile"
	if node is Projectile: return "projectile"
	var parent = node.get_parent()
	if parent == null:
		return ""
	match str(parent.name):
		"Entities":
			if node is Player: return "player"
			if node is Boss: return "elite"
			if node is Enemy: return "enemy"
			if node is Neutral: return "tree"
			if node is Pet: return "pet"
			return "structure"
		"Materials": return "material"
		"Consumables": return "consumable"
		"Births": return "birth"
		"PlayerProjectiles": return "projectile"
		"EnemyProjectiles": return "enemy_projectile"
		"Explosions": return "explosion"
	return ""

func _register(node):
	if not is_instance_valid(node) or not node is Node2D or not node.is_inside_tree():
		return
	var id = node.get_instance_id()
	if proxies.has(id): return
	var kind = _kind(node)
	if kind == "": return
	var key = node.filename
	if node is Consumable and node.consumable_data != null: key = node.consumable_data.my_id
	if node is Weapon: key = node.weapon_id
	if node is Player:
		var character = RunData.get_player_character(node.player_index)
		if character != null: key = character.my_id
	if node is Enemy and factory.manifest.has("enemy:" + node.enemy_id):
		key = "enemy:" + node.enemy_id
	var visual = factory.create_weapon(key, node.stats is MeleeWeaponStats, node.tier) if node is Weapon else factory.create(kind, key)
	if node is Enemy and not factory.manifest.has(key):
		factory.decorate_enemy(visual, node.enemy_id)
	world.add_child(visual)
	if node is Player: PlayerLocatorArt.attach(visual,node.player_index,factory)
	proxies[id] = {"source": weakref(node), "visual": visual, "kind": kind, "asset_key": key, "tier": node.tier if node is Weapon else -1, "last": node.global_position, "active": false, "shots": 0, "base_scale": visual.scale}
	if node is Enemy:
		var warning = Spatial.new()
		visual.add_child(warning)
		if kind == "elite": warning.translation.y = 0.9
		factory.box(warning, Vector3(0, 1.85, 0), Vector3(0.1, 0.3, 0.1), Color("ffb54e"), true)
		factory.ball(warning, Vector3(0, 1.61, 0), Vector3.ONE * 0.1, Color("ffb54e"), true)
		warning.visible = false
		visual.set_meta("warning", warning)
	if node is Unit and not node.is_connected("took_damage", self, "_on_damage"):
		node.connect("took_damage", self, "_on_damage")
	if node is Player and not node.is_connected("healed",self,"_on_healing"):
		node.connect("healed",self,"_on_healing")
	elif node is Enemy and not node.is_connected("healed",self,"_on_enemy_healed"):
		node.connect("healed",self,"_on_enemy_healed")
	if node is Entity and not node.is_connected("died", self, "_on_death"):
		node.connect("died", self, "_on_death")

func to_world(pos: Vector2, height = 0.0):
	return Vector3(pos.x / PIXELS, height, pos.y / (PIXELS * sin(TILT)))

func _process(delta):
	elapsed += delta
	# Deduplication only needs this frame; retain no stale player entries.
	for player_index in healing_visual_frames.keys():
		if healing_visual_frames[player_index] < Engine.get_idle_frames():
			healing_visual_frames.erase(player_index)
	var size = main.get_viewport().get_visible_rect().size
	if viewport.size != size:
		viewport.size = size
		screen.rect_size = size
	var camera2d = main.get_node("Camera")
	var center = to_world(camera2d.get_camera_screen_center())
	camera.size = size.y * camera2d.zoom.y / PIXELS
	camera.translation = center + Vector3(0, sin(TILT), cos(TILT)) * 55.0
	camera.rotation = Vector3(-TILT, 0, 0)
	for id in proxies.keys():
		var record = proxies[id]
		var source = record.source.get_ref()
		if source == null or not source.is_inside_tree():
			record.visual.queue_free()
			proxies.erase(id)
			continue
		var active = source.is_visible_in_tree()
		if source is Entity: active = active and not source.dead
		if source is Scapegoat and source.heal_particles.emitting:
			active = source.is_visible_in_tree()
		# Pooled drops can be reused for a different supply type.
		var replacement = null
		if source is Consumable and source.consumable_data != null and record.asset_key != source.consumable_data.my_id:
			record.asset_key = source.consumable_data.my_id
			replacement = factory.create("consumable",record.asset_key)
		elif source is Weapon and record.tier != source.tier:
			record.tier = source.tier
			replacement = factory.create_weapon(source.weapon_id,source.stats is MeleeWeaponStats,source.tier)
		if replacement != null:
			record.visual.queue_free()
			record.visual = replacement
			record.base_scale = replacement.scale
			world.add_child(replacement)
		var visual = record.visual
		visual.visible = enabled and active
		if not active:
			if visual.has_meta("animator"): visual.get_meta("animator").playback_speed = 0
			record.active = false
			continue
		var kind = record.kind
		_update_observed_state(source,visual,record)
		_update_status_fx(source,visual,kind)
		var height = 0.0
		var pos = source.global_position
		if kind == "weapon":
			pos = source.sprite.global_position
			height = 0.65
			var angle = source.sprite.global_rotation
			visual.rotation.y = -atan2(sin(angle) / sin(TILT), cos(angle))
			if source._nb_shots_taken != record.shots:
				record.shots = source._nb_shots_taken
				_burst(to_world(source.muzzle.global_position, height), Color("ffe5a0"), 4, 0.15)
		elif kind == "projectile" or kind == "enemy_projectile":
			height = 0.55
			if source is Projectile:
				visual.rotation.y = -atan2(source.velocity.y / sin(TILT), source.velocity.x)
				var collision = source.get_node_or_null("Hitbox/Collision")
				if collision != null:
					if collision.shape is CircleShape2D:
						var diameter = max(0.1, collision.shape.radius * 2.0 * abs(collision.global_scale.x) / PIXELS)
						visual.scale = Vector3.ONE * diameter / (0.22 if kind == "enemy_projectile" else 0.32)
					elif collision.shape is RectangleShape2D:
						var dimensions = collision.shape.extents * 2.0 * collision.global_scale.abs() / PIXELS
						visual.scale = Vector3(max(0.15, dimensions.x) / 0.32, 1, max(0.06, dimensions.y) / 0.065)
						pos = collision.global_position
						var angle = collision.global_rotation
						visual.rotation.y = -atan2(sin(angle) / sin(TILT), cos(angle))
		elif kind in ["enemy", "elite", "player", "pet"]:
			var motion = pos - record.last
			if visual.has_meta("warning"):
				var anim = source._animation_player.current_animation
				visual.get_meta("warning").visible = "shoot" in anim or "charge" in anim or "attack" in anim
			if visual.has_meta("animator"):
				visual.get_meta("animator").playback_speed = 1.0 if kind == "player" else clamp(motion.length() / max(delta, 0.001) / 100.0, 0.0, 2.5)
			if motion.length_squared() > 0.001:
				visual.rotation.y = atan2(motion.x, motion.y / sin(TILT))
				if kind == "player": visual.rotation.y += PI
				height = abs(sin(elapsed * 10.0 + id)) * 0.045
			if source is Unit and source._is_burning and int(elapsed * 12.0) != int((elapsed - delta) * 12.0):
				_burn_ember(to_world(pos, 0.6))
		elif kind == "structure":
			_update_structure_aim(visual,source,record)
		elif kind == "material":
			visual.rotation.y += delta * 1.5
		elif kind == "explosion":
			var collision = source.get_node_or_null("Hitbox/Collision")
			if collision != null and collision.shape is CircleShape2D:
				var radius = collision.shape.radius * abs(collision.global_scale.x) / PIXELS
				visual.scale = Vector3(radius * 2.0, radius * 0.55, radius * 2.0 / sin(TILT))
			if not record.active: _burst(to_world(pos, 0.25), Color("ff9a42"), 12, 0.5)
		visual.translation = to_world(pos, height)
		pet_status_art.update(source,visual,factory,TILT)
		pet_action_art.update(source,visual,factory)
		catling_aim_art.update(source,visual,factory,self)
		birth_status_art.update(source,visual)
		torch_flame_art.update(source,visual,factory,self)
		record.last = pos
		record.active = true
	for i in range(effects.size() - 1, -1, -1):
		var effect = effects[i]
		effect.life -= delta
		if effect.life <= 0:
			effect.node.queue_free()
			effects.remove(i)
		else:
			if effect.get("burn",false):
				effect.node.translation += effect.velocity * delta
				BurnArt.update(effect.node,1.0-effect.life/effect.duration)
				continue
			if not effect.get("pulse",false):
				effect.node.translation += effect.velocity * delta
				effect.velocity.y -= delta * 3.0
			if effect.get("pulse",false):
				var progress = 1.0-effect.life/effect.duration
				effect.node.scale = Vector3.ONE * (0.5+progress*1.5)
			else:
				effect.node.scale = Vector3.ONE * effect.life / effect.duration

func _update_observed_state(source,visual,record):
	if source is EvilMob:
		observed_state_art.evolution(visual,source.evolution,record.base_scale,factory)
	elif source is Landmine and source._sprite != null:
		observed_state_art.mine(visual,source.pressed_sprite != null and source._sprite.texture==source.pressed_sprite,record.base_scale,factory,elapsed)

func _update_status_fx(source,visual,kind):
	var cursed=false
	if source is Enemy:
		for behavior in source.effect_behaviors.get_children():
			if behavior is CurseEnemyEffectBehavior:
				cursed=true
				break
	elif source is Weapon or source is Structure or source is Pet:
		cursed=source.is_cursed
	status_fx_art.cursed(visual,cursed,kind,factory,elapsed)
	if source is Scapegoat:
		status_fx_art.recovering(visual,source.heal_particles.emitting,factory,elapsed)

func _update_structure_aim(visual,source,record):
	# Structures authored with a barrel use local -Z as forward. Garden inherits
	# Turret for its timer, but grows fruit and must never turn to face targets.
	if not source is Turret or source is Garden: return
	var aim = Vector2.ZERO
	if source._nb_shots_taken != record.shots:
		record.shots = source._nb_shots_taken
		record.shot_angle = source._next_proj_rotation
		record.aim_until = elapsed + 0.10
	if elapsed < record.get("aim_until",0.0):
		# Observe the game's sampled firing angle, including its existing spread.
		# Do not resample RNG, select targets, or alter the projectile's origin.
		aim = Vector2(cos(record.shot_angle),sin(record.shot_angle))
	elif source._current_target.size() > 0 and is_instance_valid(source._current_target[0]):
		aim = source._current_target[0].global_position - source.global_position
	if aim.length_squared() > 0.000001:
		visual.rotation.y = atan2(-aim.x,-aim.y/sin(TILT))
		visual.set_meta("turret_aim_direction",aim.normalized())
		visual.set_meta("turret_aim_shots",record.shots)


func _burn_ember(pos):
	if not enabled or not ProgressData.settings.visual_effects or effects.size() >= 160: return
	var node = BurnArt.create(factory)
	world.add_child(node)
	node.translation = pos + Vector3(visual_rng.randf_range(-0.16,0.16),0,visual_rng.randf_range(-0.12,0.12))
	node.rotation = Vector3(0,visual_rng.randf_range(-PI,PI),visual_rng.randf_range(-0.2,0.2))
	effects.append({"node":node,"velocity":Vector3(visual_rng.randf_range(-0.12,0.12),0.65,visual_rng.randf_range(-0.12,0.12)),"life":0.4,"duration":0.4,"burn":true})

func _pulse(pos,color,radius,duration):
	if not enabled or not ProgressData.settings.visual_effects or effects.size() >= 160: return
	var node = Spatial.new()
	world.add_child(node)
	node.translation = pos
	var art = factory.PropArt.new()
	art.f = factory
	art.ring(node,radius,color)
	effects.append({"node":node,"velocity":Vector3.ZERO,"life":duration,"duration":duration,"pulse":true})

func _burst(pos, color, count, duration):
	if not enabled or not ProgressData.settings.visual_effects: return
	for i in count:
		if effects.size() >= 160: break
		var node = Spatial.new()
		world.add_child(node)
		node.translation = pos
		factory.ball(node, Vector3.ZERO, Vector3(0.065,0.19,0.065), color, true)
		node.rotation = Vector3(visual_rng.randf_range(-1,1),0,visual_rng.randf_range(-1,1))
		effects.append({"node": node, "velocity": Vector3(visual_rng.randf_range(-1.8, 1.8), visual_rng.randf_range(0.5, 2.5), visual_rng.randf_range(-1.8, 1.8)), "life": duration, "duration": duration})

func _on_damage(unit, _value, _direction, critical, dodge, protected, _armor, _args, _hit_type, _one_shot):
	if dodge: return
	var color = Color("73d5ff") if protected else Color("ffcd72")
	_burst(to_world(unit.global_position, 0.6), color, 9 if critical else 4, 0.3)

func _on_death(unit, args):
	if not args.cleaning_up: _burst(to_world(unit.global_position, 0.5), Color("84996b"), 9, 0.5)

func _on_healing(_value, player_index, _tracking_key = 0):
	if player_index >= 0 and player_index < main._players.size():
		# RunData healing can synchronously emit Player.healed: render once per frame.
		var frame=Engine.get_idle_frames()
		if healing_visual_frames.get(player_index,-1)==frame:return
		healing_visual_frames[player_index]=frame
		_pulse(to_world(main._players[player_index].global_position,0.04),Color("70ffa7"),0.35,0.55)
		_burst(to_world(main._players[player_index].global_position, 0.5), Color("70ffa7"), 8, 0.65)

func _on_enemy_healed(enemy):
	if not is_instance_valid(enemy):return
	_pulse(to_world(enemy.global_position,0.04),Color("70ffa7"),0.3,0.5)
	_burst(to_world(enemy.global_position,0.5),Color("70ffa7"),4,0.45)

func _on_level_up(player_index):
	if player_index < main._players.size():
		_pulse(to_world(main._players[player_index].global_position,0.04),Color("79e8ff"),0.6,0.75)
		_burst(to_world(main._players[player_index].global_position, 0.7), Color("79e8ff"), 16, 0.8)

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_F8:
		enabled = not enabled
		screen.visible = enabled
		viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if enabled else Viewport.UPDATE_DISABLED
		for node in original_modulates:
			if is_instance_valid(node):
				node.modulate = original_modulates[node] if not enabled else Color(1, 1, 1, 0)

func _build_arena():
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("111f2b")
	env.ambient_light_color = Color("b2d6dd")
	env.ambient_light_energy = 0.72
	environment.environment = env
	world.add_child(environment)
	var sun = DirectionalLight.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color("ffe4bc")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_bias = 0.025
	sun.directional_shadow_max_distance = 85.0
	world.add_child(sun)
	var rect = ZoneService.get_current_zone_rect()
	var start = to_world(rect.position)
	var end = to_world(rect.end)
	var extent = end - start
	var center = (start + end) * 0.5
	factory.box(world, center - Vector3(0, 0.32, 0), Vector3(extent.x + 2, 0.5, extent.z + 2), Color("263d48"))
	# A single floor draw call, including tile seams and lane markings.
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(extent.x + 1, extent.z + 1)
	var floor_node = MeshInstance.new()
	floor_node.mesh = floor_mesh
	floor_node.translation = center
	var floor_mat = ShaderMaterial.new()
	floor_mat.shader = load("res://combat3d/mall_floor.shader")
	floor_mat.set_shader_param("floor_size", floor_mesh.size)
	floor_node.material_override = floor_mat
	world.add_child(floor_node)
	for side in [-1, 1]:
		var x = center.x + side * (extent.x * 0.5 + 0.3)
		factory.box(world, Vector3(x, 0.55, center.z), Vector3(0.4, 1.1, extent.z + 1), Color("23323e"))
		for z in range(2, int(extent.z), 5):
			factory.box(world, Vector3(x, 1.15, start.z + z), Vector3(0.45, 0.08, 1.2), Color("70d9cf"), true)
	# Imported storefronts line the perimeter; the central combat lane stays open.
	for side in [-1, 1]:
		var x = start.x + 1.2 if side == -1 else end.x - 1.2
		for z in range(3, int(extent.z) - 3, 6):
			if z == 15 and side == 1:
				_place_environment("escalator", Vector3(x, 0, start.z + z), 0, Vector3.ONE)
				continue
			_place_environment("shopfront", Vector3(x, 0, start.z + z), -side * 40, Vector3(0.85, 0.85, 0.28))
		for z in range(6, int(extent.z) - 3, 12):
			if z == 18 and side == 1: continue
			var supply = "supply_shelf" if z == 18 and side == -1 else "vending_machine"
			if z == 30: supply = "lamp"
			_place_environment(supply, Vector3(x, 0, start.z + z), -side * 25, Vector3.ONE)
		for z in range(12, int(extent.z) - 3, 12):
			if z == 12 and side == 1: continue
			var fixture = "kiosk" if z == 12 and side == -1 else "bench"
			if z == 24: fixture = "pillar"
			_place_environment(fixture, Vector3(x, 0, start.z + z), -side * 35, Vector3.ONE)
		_place_environment("shopping_cart", Vector3(x, 0, end.z - 3.0), side * 30, Vector3.ONE)
		_place_environment("generator", Vector3(x - side * 0.9, 0, end.z - 5.2), -side * 25, Vector3.ONE)
	factory.box(world, Vector3(center.x, 0.55, start.z + 0.15), Vector3(extent.x, 1.1, 0.3), Color("293d46"))
	for i in range(5):
		factory.box(world, Vector3(center.x - 2.0 + i, 1.15, start.z + 0.15), Vector3(0.65, 0.12, 0.4), Color("f58257"), true)
	# Emergency barricade at the lower edge, clear central firing lane.
	_place_environment("security_gate", Vector3(center.x, 0, start.z + 3.0), 0, Vector3.ONE)
	_place_environment("bench", Vector3(center.x - 3.0, 0, start.z + 3.0), 0, Vector3.ONE)
	for x in range(1, int(extent.x), 2):
		_place_environment("barricade", Vector3(start.x + x, 0, end.z - 0.4), 0, Vector3.ONE)

func _place_environment(identity, position, yaw, dimensions):
	var key = "environment:" + identity
	if not factory.manifest.has(key): return
	var visual = factory.create("environment", key)
	visual.name = identity
	world.add_child(visual)
	visual.scale = dimensions
	visual.rotation_degrees.y = yaw
	visual.translation = position
