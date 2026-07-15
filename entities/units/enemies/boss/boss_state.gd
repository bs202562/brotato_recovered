class_name BossState
extends Node2D

@export var hp_start: float = 0.5
@export var timer_start: float = 45.0

@onready var movement_behavior = $MovementBehavior
@onready var attack_behavior = $AttackBehavior
