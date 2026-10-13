class_name EnemyAttackDefinition
extends RefCounted

var id: String = "attack"
var attack_name: String = "Attack"
var type: String = "melee"
var damage: int = 10
var element: int = ElementalTypes.ElementType.NONE
var attack_range: float = 40.0
var cooldown: float = 1.0
var windup: float = 0.0
var hitbox_size: Vector2 = Vector2.ONE * 20.0
var knockback: Vector2 = Vector2.ZERO
var status_effects: Array = []
var behavior: Dictionary = {}

func _init(p_id: String = "attack", p_data: Dictionary = {}) -> void:
	id = p_id
	if p_data.is_empty():
		return
	_apply_data(p_data)

func apply_data(p_data: Dictionary) -> void:
	_apply_data(p_data)

func _apply_data(p_data: Dictionary) -> void:
	if p_data.has("id"):
		id = String(p_data["id"])
	if p_data.has("attack_name"):
		attack_name = String(p_data["attack_name"])
	if p_data.has("type"):
		type = String(p_data["type"])
	if p_data.has("damage"):
		damage = int(p_data["damage"])
	if p_data.has("element"):
		element = int(p_data["element"])
	if p_data.has("range"):
		attack_range = float(p_data["range"])
	if p_data.has("attack_range"):
		attack_range = float(p_data["attack_range"])
	if p_data.has("cooldown"):
		cooldown = float(p_data["cooldown"])
	if p_data.has("windup"):
		windup = float(p_data["windup"])
	if p_data.has("hitbox_size") and p_data["hitbox_size"] is Vector2:
		hitbox_size = p_data["hitbox_size"]
	if p_data.has("knockback") and p_data["knockback"] is Vector2:
		knockback = p_data["knockback"]
	if p_data.has("status_effects") and p_data["status_effects"] is Array:
		status_effects = p_data["status_effects"].duplicate()
	if p_data.has("behavior") and p_data["behavior"] is Dictionary:
		behavior = p_data["behavior"].duplicate()
