class_name HealthComponent
extends Node
signal health_changed(current_health: int)
signal died

@export var max_health: int = 100
var current_health: int

func _ready() -> void:
	if ConfigManager and max_health == 100:
		max_health = ConfigManager.get_int("entities", "default_health.max_health", max_health)
	current_health = max_health

func take_damage(damage: int) -> void:
	current_health = clampi(current_health - damage, 0, max_health)
	health_changed.emit(current_health)

	if current_health <= 0:
		died.emit()

func heal(amount: int) -> void:
	current_health = clampi(current_health + amount, 0, max_health)
	health_changed.emit(current_health)
