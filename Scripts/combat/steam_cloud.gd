class_name SteamCloud
extends Node2D

var remaining: float = 0.0
var cloud_radius: float = 0.0
var cloud_length: float = 0.0
var blind_duration: float = 0.0
var wet_charge_percent: float = 0.0
var wet_min_strength_percent: float = 0.0
var strength_percent: float = 0.0
var charge_duration: float = 0.0
var affected_enemies: Array[Node2D] = []

func _ready() -> void:
	add_to_group("SteamClouds")

func setup(
	origin: Vector2,
	duration: float,
	radius: float,
	length: float,
	p_blind_duration: float,
	p_wet_charge_percent: float,
	p_wet_min_strength_percent: float,
	p_strength_percent: float,
	p_charge_duration: float
) -> void:
	global_position = origin
	remaining = duration
	cloud_radius = radius
	cloud_length = length
	blind_duration = p_blind_duration
	wet_charge_percent = p_wet_charge_percent
	wet_min_strength_percent = p_wet_min_strength_percent
	strength_percent = p_strength_percent
	charge_duration = p_charge_duration
	z_index = -1
	queue_redraw()

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or remaining <= 0.0:
		return

	_apply_cloud_blindness()
	remaining = maxf(remaining - delta, 0.0)
	if remaining == 0.0:
		_apply_wet_charge()
		queue_free()

func _apply_cloud_blindness() -> void:
	var half_length := cloud_length * 0.5
	for node in get_tree().get_nodes_in_group("Enemies"):
		if not node is Node2D or not node.has_method("apply_blind"):
			continue
		var enemy := node as Node2D
		if enemy.get("is_dead") == true or not _contains(enemy.global_position, half_length):
			continue
		if not affected_enemies.has(enemy):
			affected_enemies.append(enemy)
			var blindness_duration := minf(blind_duration, remaining)
			if enemy.has_method("get_status_duration"):
				blindness_duration = minf(
					blindness_duration,
					float(enemy.call("get_status_duration", "blind", blindness_duration))
				)
			enemy.call("apply_blind", blindness_duration)

func _contains(world_position: Vector2, half_length: float) -> bool:
	var offset := world_position - global_position
	var closest_point := Vector2(clampf(offset.x, -half_length, half_length), 0.0)
	return offset.distance_squared_to(closest_point) <= cloud_radius * cloud_radius

func _apply_wet_charge() -> void:
	if strength_percent < wet_min_strength_percent:
		return
	for enemy in affected_enemies:
		if not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var gauge := enemy.get("elemental_gauge") as ElementalGauge
		if gauge == null:
			push_error("[SteamCloud] Affected enemy is missing its elemental gauge")
			continue
		gauge.set_value(
			ElementalTypes.ElementType.WATER,
			gauge.charge_threshold * wet_charge_percent / 100.0,
			charge_duration
		)

func _draw() -> void:
	var color := Color(0.78, 0.88, 0.94, 0.38)
	var half_length := cloud_length * 0.5
	var points := PackedVector2Array()
	for i in range(9):
		var angle := -PI * 0.5 + PI * float(i) / 8.0
		points.append(Vector2(half_length + cos(angle) * cloud_radius, sin(angle) * cloud_radius))
	for i in range(9):
		var angle := PI * 0.5 + PI * float(i) / 8.0
		points.append(Vector2(-half_length + cos(angle) * cloud_radius, sin(angle) * cloud_radius))
	draw_colored_polygon(points, color)
