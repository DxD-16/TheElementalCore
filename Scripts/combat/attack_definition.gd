class_name AttackDefinition
extends Resource

@export var attack_name: String = "Strike"
@export var damage: int = 10
@export var knockback: float = 100.0
@export var duration: float = 0.4
@export var animation_name: String = ""
@export var animation_frames: SpriteFrames
@export var element: int = -1
@export var element_charge: float = 0.0
@export var hitboxes: Array[WeaponHitboxDefinition] = []
