extends Node3D

@export var speed: float = 0.25


func _process(delta: float) -> void:
	rotate_z(speed * delta)
