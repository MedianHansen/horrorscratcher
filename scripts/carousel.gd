extends Node3D

@export var speed: float = 0.6


func _process(delta: float) -> void:
	rotate_y(speed * delta)
