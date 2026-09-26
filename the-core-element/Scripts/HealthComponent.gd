class_name HealthComponent
extends Node
signal health_changed(current_health: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(damage: int) -> void:
	current_health = max_health if current_health - damage > max_health else current_health - damage
	current_health = max(0, current_health)
	
	health_changed.emit(current_health)
	
	if current_health <= 0:
		died.emit()
