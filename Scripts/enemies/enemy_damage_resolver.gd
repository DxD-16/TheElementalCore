class_name EnemyDamageResolver
extends RefCounted

static func calculate_damage(enemy: Node, base_damage: int, damage_type: int = DamageTypes.Type.PHYSICAL) -> int:
	if enemy == null:
		return base_damage
	if damage_type == DamageTypes.Type.PURE:
		return maxi(base_damage, 0)

	var definition = null
	if enemy.has_method("get_definition"):
		definition = enemy.get_definition()
	if definition == null and enemy.has_meta("enemy_definition"):
		definition = enemy.get_meta("enemy_definition")
	if definition == null:
		return base_damage

	var resistance_key := DamageTypes.to_key(damage_type)
	if resistance_key.is_empty():
		push_error("[EnemyDamageResolver] Unknown damage type: %d" % damage_type)
		return maxi(base_damage, 0)

	var resistance: float = float(definition.resistances.get(resistance_key, 0.0))
	if enemy.has_method("get_effective_resistance"):
		resistance = float(enemy.get_effective_resistance(damage_type, resistance))
	var damage_multiplier := 1.0 - resistance
	return int(max(0, round(float(base_damage) * damage_multiplier)))
