class_name BurningParticles
extends CPUParticles2D

export (Gradient) var red_gradient
export (Gradient) var red_gradient_secondary
export (Gradient) var blue_gradient
export (Gradient) var blue_gradient_secondary

onready var secondary_particles: CPUParticles2D = $secondaryParticle
onready var _collision = $SpreadArea / CollisionShape2D
onready var main: Main = get_tree().current_scene

var burning_data: BurningData
var bodies = []
var emit_remaining: = 0.0

signal stop_emitting(burning_particles)

func _physics_process(delta: float) -> void :
	if secondary_particles.emitting != emitting:
		secondary_particles.emitting = emitting
	
	
	
	if visible and not emitting:
		if emit_remaining == 0.0:
			emit_remaining = lifetime * 1.2
		else:
			emit_remaining -= delta
			if emit_remaining < 0.0:
				emit_remaining = 0.0
				visible = false
	else:
		emit_remaining = 0.0

	if _collision.disabled: return

	if burning_data != null and burning_data.spread > 0 and bodies.size() > 0:
		for body in bodies:
			if is_instance_valid(body) and not body.dead and not body._is_burning:
				burning_data.spread = max(0, burning_data.spread - 1) as int
				body.apply_burning(burning_data)
				burning_data.spread = 0
				deactivate_spread()
				break


func start_emitting() -> void :
	emitting = true
	visible = true
	main._on_emit_fire_particle(self)
	_update_color()


func stop_emitting() -> void :
	emit_signal("stop_emitting", self)
	emitting = false
	deactivate_spread()


func _update_color() -> void :
	if burning_data != null:
		var first_scaling_stat = Utils.get_first_scaling_stat(burning_data.scaling_stats)
		if first_scaling_stat == Keys.stat_elemental_damage_hash:
			color_ramp = red_gradient
			secondary_particles.color_ramp = red_gradient_secondary
		if first_scaling_stat == Keys.stat_engineering_hash:
			color_ramp = blue_gradient
			secondary_particles.color_ramp = blue_gradient_secondary


func activate_spread() -> void :
	_collision.set_deferred("disabled", false)


func deactivate_spread() -> void :
	_collision.set_deferred("disabled", true)


func _on_SpreadArea_body_entered(body: Node) -> void :
	if is_instance_valid(body) and not body.dead and body != get_parent():
		bodies.push_back(body)


func _on_SpreadArea_body_exited(body: Node) -> void :
	bodies.erase(body)
