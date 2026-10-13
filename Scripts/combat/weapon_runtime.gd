class_name WeaponRuntime
extends RefCounted

var weapon_data: WeaponData
var combo_index: int = 0
var is_attacking: bool = false
var next_attack_buffered: bool = false
var attack_timer: float = 0.0

func _init(p_weapon_data: WeaponData = null) -> void:
	weapon_data = p_weapon_data
	if weapon_data == null:
		weapon_data = WeaponData.new("fists", "Fists")
		weapon_data.combo_steps = [
			{"name": "Swing 1", "damage": 10, "knockback": 100.0, "time": 0.3, "element": ElementalTypes.ElementType.NONE, "status": []},
			{"name": "Swing 2", "damage": 18, "knockback": 150.0, "time": 0.3, "element": ElementalTypes.ElementType.NONE, "status": []},
			{"name": "Swing 3", "damage": 20, "knockback": 200.0, "time": 0.3, "element": ElementalTypes.ElementType.NONE, "status": []}
		]

func get_attack_step() -> Dictionary:
	if weapon_data == null:
		return {}
	return weapon_data.get_combo_step(combo_index)

func advance_combo() -> void:
	combo_index += 1
	if combo_index >= weapon_data.get_combo_size():
		reset_combo()

func reset_combo() -> void:
	combo_index = 0
	next_attack_buffered = false
	is_attacking = false
	attack_timer = 0.0
