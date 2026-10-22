class_name HealItemBehavior
extends ItemBehavior

@export_range(1, 9999, 1) var heal_amount: int = 50

func use(user: Node, _item: ItemInstance) -> bool:
	if user == null:
		push_warning("[HealItemBehavior] Cannot heal without a user")
		return false
	var health_component := user.get_node_or_null("HealthComponent")
	if health_component == null or not health_component.has_method("heal"):
		push_warning("[HealItemBehavior] User has no HealthComponent with heal()")
		return false
	health_component.call("heal", heal_amount)
	return true
