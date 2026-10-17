class_name WeaponRuntime
extends RefCounted

var weapon_data: WeaponData
var combo_index: int = 0
var is_attacking: bool = false
var next_attack_buffered: bool = false
var attack_timer: float = 0.0

func _init(p_weapon_data: WeaponData = null) -> void:
	weapon_data = p_weapon_data

func get_attack_step() -> AttackDefinition:
	if weapon_data == null:
		return null
	return weapon_data.get_attack_step(combo_index)

func advance_combo() -> void:
	combo_index += 1
	if combo_index >= weapon_data.get_combo_size():
		reset_combo()

func reset_combo() -> void:
	combo_index = 0
	next_attack_buffered = false
	is_attacking = false
	attack_timer = 0.0
