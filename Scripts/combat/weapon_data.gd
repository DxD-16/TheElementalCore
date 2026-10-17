class_name WeaponData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var weapon_type: String = "melee"
@export var element: int = ElementalTypes.ElementType.NONE
@export var base_damage: int = 10
@export var base_knockback: float = 100.0
@export var base_attack_speed: float = 1.0
@export var combo_reset_time: float = 1.0
@export var attack_sprite_frames: SpriteFrames
@export var weapon_scene: PackedScene
@export var attacks: Array[AttackDefinition] = []

func get_attack_step(index: int) -> AttackDefinition:
	if attacks.is_empty():
		return null
	return attacks[clampi(index, 0, attacks.size() - 1)]

func get_combo_size() -> int:
	return attacks.size()
