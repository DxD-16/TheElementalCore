
class_name FistsWeapon
extends Node2D

signal attack_finished
signal attack_step_started(combo_step: int)

@export_category("Combo Settings")
@export var combo_reset_time: float = 0.6  # Время, за которое комбо сбрасывается, если не бить дальше

# Данные урона и отталкивания для каждого из 4 ударов
@export var damage_list: Array[int] = [10, 18, 20, 40]
@export var knockback_list: Array[float] = [100.0, 150.0, 200.0, 400.0]
@export var attack_time_list: Array[float] = [0.4, 0.4, 0.5, 0.8]

var current_combo: int = 0          # Текущий шаг комбо (0, 1, 2, 3)
var is_attacking: bool = false      # Идет ли сейчас анимация/удар
var combo_timer: float = 0.0        # Таймер окна для следующего удара
var next_attack_buffered: bool = false # Буфер нажатия

var hit_enemies_this_swing: Array[Node2D] = [] # Список уже задетых врагов за текущий взмах

@onready var hit_box: Area2D = $AttackArea
@onready var shapes: Array[Node] = $AttackArea.get_children() # Все коллайдеры ударов

func _ready() -> void:
	disable_all_hitboxes()

func _process(delta: float) -> void:
	# Обработка таймера сброса комбо
	if combo_timer > 0 and not is_attacking:
		combo_timer -= delta
		if combo_timer <= 0:
			reset_combo()

func execute_attack() -> void:
	if is_attacking:
		return
	is_attacking = true
	combo_timer = 0.0
	hit_enemies_this_swing.clear()
	
	var safe_combo: int = clampi(current_combo, 0, damage_list.size() - 1)
	print("Выполняется удар комбо №: ", safe_combo + 1, " с уроном: ", damage_list[safe_combo])
	
	# Включаем нужный хитбокс под текущий удар
	disable_all_hitboxes()
	if safe_combo < shapes.size() and shapes[safe_combo] is CollisionShape2D:
		shapes[safe_combo].disabled = false
	
	attack_step_started.emit(safe_combo)
	
	# Длительность одного удара
	await get_tree().create_timer(attack_time_list[safe_combo]).timeout
	
	finish_attack_step()

func finish_attack_step() -> void:
	disable_all_hitboxes()
	is_attacking = false
	hit_enemies_this_swing.clear()
	
	# Переходим к следующему удару
	current_combo += 1
	if current_combo >= damage_list.size():
		reset_combo()
		attack_finished.emit()
	else:
		combo_timer = combo_reset_time
		if next_attack_buffered:
			next_attack_buffered = false
			execute_attack()
		else:
			attack_finished.emit()

func reset_combo() -> void:
	current_combo = 0
	combo_timer = 0.0
	next_attack_buffered = false
	is_attacking = false
	hit_enemies_this_swing.clear()
	disable_all_hitboxes()

func disable_all_hitboxes() -> void:
	for shape in shapes:
		if shape is CollisionShape2D:
			shape.disabled = true

func _on_attack_area_body_entered(body: Node2D) -> void:
	# Защита от нанесения урона одной и той же цели несколько раз за один взмах
	if body in hit_enemies_this_swing:
		return
	hit_enemies_this_swing.append(body)
	
	if body.has_method("take_damage"):
		var index: int = clampi(current_combo, 0, damage_list.size() - 1)
		var damage: int = damage_list[index]
		
		# Точные мировые координаты активного хитбокса кулака
		var hit_pos: Vector2 = hit_box.global_position
		if index < shapes.size() and shapes[index] is Node2D:
			hit_pos = (shapes[index] as Node2D).global_position
		
		body.take_damage(damage, hit_pos)

func _on_hit_box_body_entered(body: Node2D) -> void:
	_on_attack_area_body_entered(body)
