extends TextureProgressBar

@export var delay_bar: TextureProgressBar
@export var bar_frame: TextureRect
@export var delay_interval: float = 0.4
@export var fade_duration: float = 0.5

var health_component: HealthComponent
var tween: Tween

func _ready() -> void:
	_load_config()
	# Автоматически ищем HealthComponent внутри корневого узла врага (owner)
	if owner:
		health_component = owner.find_child("HealthComponent", true, false) as HealthComponent
	
	if not health_component:
		var p = get_parent()
		while p:
			if p.has_node("HealthComponent"):
				health_component = p.get_node("HealthComponent") as HealthComponent
				break
			p = p.get_node_or_null("..")

	if health_component:
		
		max_value = health_component.max_health
		value = health_component.current_health
		
		if delay_bar:
			delay_bar.max_value = health_component.max_health
			delay_bar.value = health_component.current_health
			
		health_component.health_changed.connect(_on_health_changed)
		
		check_visibility()
	else:
		push_warning("HealthBar не смог автоматически найти HealthComponent у врага: ", name)

func _load_config() -> void:
	if ConfigManager:
		delay_interval = ConfigManager.get_float("ui_effects", "health_bar.delay_interval", delay_interval)
		fade_duration = ConfigManager.get_float("ui_effects", "health_bar.fade_duration", fade_duration)

func _on_health_changed(current_health: int) -> void:
	var previous_value = value
	value = current_health
	
	# Обновляем видимость (полоска появится, если враг ранен)
	check_visibility()

	# Логика тающего желтого следа (DelayBar)
	if current_health < previous_value and delay_bar:
		if tween and tween.is_valid():
			tween.kill()
		
		tween = create_tween().set_parallel(false)
		tween.tween_interval(delay_interval) # Задержка перед убыванием желтого следа
		tween.tween_property(delay_bar, "value", current_health, fade_duration) # Плавное убывание

func check_visibility() -> void:
	if health_component:
		# Если здоровье максимальное — полоска полностью невидима
		if health_component.current_health >= health_component.max_health:
			visible = false
			bar_frame.visible = false
			if delay_bar:
				delay_bar.visible = false
				delay_bar.value = health_component.max_health
			
		else:
			visible = true
			delay_bar.visible = true
			bar_frame.visible = true
