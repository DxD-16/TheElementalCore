class_name DamageContext
extends RefCounted

var source: Node = null
var target: Node = null
var base_damage: int = 0
var element: int = ElementalTypes.ElementType.NONE
var knockback: Vector2 = Vector2.ZERO
var attack_name: String = ""
var hit_position: Vector2 = Vector2.ZERO
var crit_chance: float = 0.0
var crit_multiplier: float = 1.0
var status_effects: Array[Dictionary] = []

func _init(
	p_source: Node = null,
	p_target: Node = null,
	p_base_damage: int = 0,
	p_element: int = ElementalTypes.ElementType.NONE,
	p_knockback: Vector2 = Vector2.ZERO,
	p_attack_name: String = "",
	p_hit_position: Vector2 = Vector2.ZERO
) -> void:
	source = p_source
	target = p_target
	base_damage = p_base_damage
	element = p_element
	knockback = p_knockback
	attack_name = p_attack_name
	hit_position = p_hit_position

func with_status(effect: Dictionary) -> DamageContext:
	status_effects.append(effect)
	return self

func copy() -> DamageContext:
	var clone := DamageContext.new()
	clone.source = source
	clone.target = target
	clone.base_damage = base_damage
	clone.element = element
	clone.knockback = knockback
	clone.attack_name = attack_name
	clone.hit_position = hit_position
	clone.crit_chance = crit_chance
	clone.crit_multiplier = crit_multiplier
	clone.status_effects = status_effects.duplicate()
	return clone
