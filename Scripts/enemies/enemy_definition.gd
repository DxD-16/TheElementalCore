class_name EnemyDefinition
extends RefCounted

var id: String = "enemy"
var display_name: String = "Enemy"
var max_health: int = 100
var move_speed: float = 60.0
var weight: float = 1.0
var horizontal_friction: float = 900.0
var detection_range: float = 240.0
var attack_range: float = 50.0
var attack_cooldown: float = 1.0
var resistances: Dictionary = {
	"physical": 0.0,
	"fire": 0.0,
	"electric": 0.0,
	"ether": 0.0,
	"ice": 0.0
}
var status_immunities: Array = []
var attack_patterns: Array = []
var drop_table: Array = []
var behavior: Dictionary = {}

func _init(p_id: String = "enemy", p_data: Dictionary = {}) -> void:
	id = p_id
	if p_data.is_empty():
		return
	_apply_data(p_data)

func apply_data(p_data: Dictionary) -> void:
	_apply_data(p_data)

func _apply_data(p_data: Dictionary) -> void:
	if p_data.has("id"):
		id = String(p_data["id"])
	if p_data.has("display_name"):
		display_name = String(p_data["display_name"])
	if p_data.has("max_health"):
		max_health = int(p_data["max_health"])
	if p_data.has("move_speed"):
		move_speed = float(p_data["move_speed"])
	if p_data.has("weight"):
		var configured_weight := float(p_data["weight"])
		if configured_weight > 0.0:
			weight = configured_weight
		else:
			push_warning("EnemyDefinition weight must be greater than zero; using %.2f" % weight)
	if p_data.has("horizontal_friction"):
		var configured_friction := float(p_data["horizontal_friction"])
		if is_finite(configured_friction) and configured_friction >= 0.0:
			horizontal_friction = configured_friction
		else:
			push_warning("EnemyDefinition horizontal_friction must be finite and non-negative; using %.1f" % horizontal_friction)
	if p_data.has("detection_range"):
		detection_range = float(p_data["detection_range"])
	if p_data.has("attack_range"):
		attack_range = float(p_data["attack_range"])
	if p_data.has("attack_cooldown"):
		attack_cooldown = float(p_data["attack_cooldown"])
	if p_data.has("resistances") and p_data["resistances"] is Dictionary:
		var configured_resistances: Dictionary = p_data["resistances"]
		for damage_type in resistances:
			if not configured_resistances.has(damage_type):
				continue
			var resistance: Variant = configured_resistances[damage_type]
			if not (resistance is int or resistance is float) or not is_finite(float(resistance)):
				push_warning("EnemyDefinition resistance '%s' must be a finite number; using 0" % damage_type)
				continue
			resistances[damage_type] = minf(float(resistance), 1.0)
	if p_data.has("status_immunities") and p_data["status_immunities"] is Array:
		status_immunities = p_data["status_immunities"].duplicate()
	if p_data.has("attack_patterns") and p_data["attack_patterns"] is Array:
		attack_patterns = p_data["attack_patterns"].duplicate()
	if p_data.has("drop_table") and p_data["drop_table"] is Array:
		drop_table = p_data["drop_table"].duplicate()
	if p_data.has("behavior") and p_data["behavior"] is Dictionary:
		behavior = p_data["behavior"].duplicate()
