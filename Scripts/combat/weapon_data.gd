class_name WeaponData
extends RefCounted

var id: String = ""
var display_name: String = ""
var weapon_type: String = "melee"
var element: int = ElementalTypes.ElementType.NONE
var base_damage: int = 10
var base_knockback: float = 100.0
var base_attack_speed: float = 1.0
var combo_steps: Array[Dictionary] = []

func _init(p_id: String = "weapon", p_display_name: String = "Weapon") -> void:
	id = p_id
	display_name = p_display_name
	combo_steps = [
		{
			"name": "Strike",
			"damage": 10,
			"knockback": 100.0,
			"time": 0.3,
			"element": ElementalTypes.ElementType.NONE,
			"status": []
		}
	]

func get_combo_step(index: int) -> Dictionary:
	if combo_steps.is_empty():
		return {}
	var safe_index := index
	if safe_index < 0:
		safe_index = 0
	if safe_index >= combo_steps.size():
		safe_index = combo_steps.size() - 1
	return combo_steps[safe_index]

func get_combo_size() -> int:
	return combo_steps.size()
