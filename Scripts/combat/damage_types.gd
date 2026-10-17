class_name DamageTypes
extends RefCounted

enum Type {
	PHYSICAL = 0,
	FIRE = 1,
	ELECTRIC = 2,
	ETHER = 3,
	ICE = 4,
	PURE = 5
}

static func from_element(element: int) -> int:
	match element:
		ElementalTypes.ElementType.FIRE:
			return Type.FIRE
		ElementalTypes.ElementType.ELECTRIC:
			return Type.ELECTRIC
		ElementalTypes.ElementType.ETHER:
			return Type.ETHER
		ElementalTypes.ElementType.ICE:
			return Type.ICE
		_:
			return Type.PHYSICAL

static func element_deals_damage(element: int) -> bool:
	return element != ElementalTypes.ElementType.WATER and element != ElementalTypes.ElementType.AIR

static func to_key(damage_type: int) -> String:
	match damage_type:
		Type.PHYSICAL:
			return "physical"
		Type.FIRE:
			return "fire"
		Type.ELECTRIC:
			return "electric"
		Type.ETHER:
			return "ether"
		Type.ICE:
			return "ice"
		_:
			return ""
