class_name EnemyProjectileRotating
extends EnemyProjectile

@export var min_target_distance: int = 100
@export var max_target_distance: int = 100
@export var speed: int = 100
@export var destroy_on_hit: bool = false
@export var damage: float = 1.0
@export var damage_increase_each_wave: float = 1.0

var actual_target_distance = 0

func shoot() -> void :
	super.shoot()
	set_damage(damage + ((RunData.current_wave - 1) * damage_increase_each_wave) as int)
	actual_target_distance = randf_range(min_target_distance, max_target_distance)


func _physics_process(delta: float) -> void :
	if position.x < actual_target_distance:
		position.x += speed * RunData.current_run_accessibility_settings.speed * delta

	super._physics_process(delta) # 4.x 移植: Godot 3 自动调用父类虚函数，4.x 需显式调用（_physics_process 为子类优先）


func _on_Hitbox_hit_something(_thing_hit: Node, _damage_dealt: int) -> void :
	if destroy_on_hit:
		stop()
