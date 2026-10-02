extends TextureProgressBar

@export var delay_bar: TextureProgressBar
@export var frame_node: Control # Ссылка на рамку/фон
@export var auto_find_player: bool = true # Автоматически искать игрока по группе/имени

var health_component: HealthComponent
var tween: Tween

## Тайминги DelayBar (загружаются из ui_effects.json)
var delay_interval: float = 0.4
var fade_duration: float = 0.5

func _ready() -> void:
	_load_ui_config()

	if auto_find_player:
		# Ищем Player по имени в текущей сцене
		var player = get_tree().get_first_node_in_group("Player")
		if not player:
			player = get_tree().current_scene.find_child("Player", true, false)

		if player:
			health_component = player.find_child("HealthComponent", true, false) as HealthComponent

	if health_component:
		# Синхронизируем настройки max_health из player.json
		var max_hp: int = health_component.max_health
		if ConfigManager:
			max_hp = ConfigManager.get_int("player", "health.max_health", max_hp)
			health_component.max_health = max_hp
			health_component.current_health = max_hp

		max_value = health_component.max_health
		value = health_component.current_health

		# Автоматически найти delay_bar по имени-сестре если не назначен в инспекторе
		if not delay_bar:
			var parent = get_parent()
			if parent:
				delay_bar = parent.get_node_or_null("HPDelayBar") as TextureProgressBar

		if delay_bar:
			delay_bar.max_value = health_component.max_health
			delay_bar.value = health_component.current_health

		health_component.health_changed.connect(_on_health_changed)
	else:
		push_warning("PlayerHealthBar не смог найти HealthComponent у игрока!")

func _load_ui_config() -> void:
	if ConfigManager:
		delay_interval = ConfigManager.get_float("ui_effects", "health_bar.delay_interval", delay_interval)
		fade_duration = ConfigManager.get_float("ui_effects", "health_bar.fade_duration", fade_duration)

func _on_health_changed(current_health: int) -> void:
	var previous_value = value
	value = current_health

	# Плавный желтый след (DelayBar) при получении урона
	if current_health < previous_value and delay_bar:
		if tween and tween.is_valid():
			tween.kill()

		tween = create_tween().set_parallel(false)
		tween.tween_interval(delay_interval)
		tween.tween_property(delay_bar, "value", current_health, fade_duration)
