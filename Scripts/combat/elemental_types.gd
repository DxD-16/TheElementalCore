class_name ElementalTypes
extends RefCounted

enum ElementType {
	NONE = 0,
	FIRE = 1,
	ELECTRIC = 2,
	ETHER = 3,
	ICE = 4,
	WATER = 5,
	AIR = 6
}

static func element_to_string(element: int) -> String:
	match element:
		ElementType.FIRE:
			return "Fire"
		ElementType.ELECTRIC:
			return "Electric"
		ElementType.ETHER:
			return "Ether"
		ElementType.ICE:
			return "Ice"
		ElementType.WATER:
			return "Water"
		ElementType.AIR:
			return "Air"
		_:
			return "None"

static func from_string(value: String) -> int:
	var key := value.strip_edges().to_lower()
	match key:
		"fire":
			return ElementType.FIRE
		"electric", "lightning":
			return ElementType.ELECTRIC
		"ether":
			return ElementType.ETHER
		"ice":
			return ElementType.ICE
		"water":
			return ElementType.WATER
		"air":
			return ElementType.AIR
		_:
			return ElementType.NONE

static func is_elemental(element: int) -> bool:
	return element != ElementType.NONE
