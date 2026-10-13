class_name EnemyDamageResolver
extends RefCounted

static func calculate_damage(enemy: Node, base_damage: int, element: int = ElementalTypes.ElementType.NONE) -> int:
	if enemy == null:
		return base_damage

	var definition = null
	if enemy.has_method("get_definition"):
		definition = enemy.get_definition()
	if definition == null and enemy.has_meta("enemy_definition"):
		definition = enemy.get_meta("enemy_definition")
	if definition == null:
		return base_damage

	var multiplier: float = 1.0
	if definition.resistances.has(element):
		multiplier *= float(definition.resistances[element])
	if definition.vulnerabilities.has(element):
		multiplier *= float(definition.vulnerabilities[element])

	return int(max(0, round(float(base_damage) * multiplier)))
