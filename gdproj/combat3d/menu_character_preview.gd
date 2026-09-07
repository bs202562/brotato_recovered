extends TextureRect
# A display-only world: character effects and inventory remain in CharacterPanelUI.
const Factory = preload("res://combat3d/visual_factory.gd")
var factory = Factory.new()
var viewport
var world
var current
var identity = ""

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand = true
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect_position = Vector2(-115,-145)
	rect_size = Vector2(230,260)
	pause_mode = Node.PAUSE_MODE_PROCESS
	viewport = Viewport.new()
	viewport.size = Vector2(320,360)
	viewport.own_world = true
	viewport.transparent_bg = true
	viewport.render_target_v_flip = true
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS
	viewport.msaa = Viewport.MSAA_2X
	viewport.hdr = false
	add_child(viewport)
	texture = viewport.get_texture()
	world = Spatial.new()
	viewport.add_child(world)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_color = Color("c7d7db")
	environment.environment.ambient_light_energy = 0.8
	world.add_child(environment)
	var light = DirectionalLight.new()
	light.rotation_degrees = Vector3(-38,-25,0)
	light.light_energy = 0.85
	world.add_child(light)
	var camera = Camera.new()
	camera.projection = Camera.PROJECTION_ORTHOGONAL
	camera.size = 2.4
	camera.translation = Vector3(0.35,1.65,3)
	world.add_child(camera)
	camera.look_at(Vector3(0,0.9,0),Vector3.UP)
	camera.current = true
	connect("visibility_changed",self,"_update_visibility")
	_update_visibility()

func show_character(character_id: String):
	if identity == character_id: return
	identity = character_id
	if current != null:
		world.remove_child(current)
		current.queue_free()
	current = factory.create("player",identity)
	current.rotation_degrees.y = 180
	world.add_child(current)

func _update_visibility():
	viewport.render_target_update_mode = Viewport.UPDATE_ALWAYS if is_visible_in_tree() else Viewport.UPDATE_DISABLED
