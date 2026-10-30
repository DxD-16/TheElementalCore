class_name ActionGate
extends RefCounted

func can_perform_action(actor: Node, action_name: String) -> bool:
	if actor == null:
		return false
	if action_name == "" or action_name == "none":
		return false

	if actor.has_method("is_controls_locked") and actor.is_controls_locked():
		return false
	if actor.get("is_dead") == true:
		return false

	for property in actor.get_property_list():
		if str(property.get("name", "")) != "status_effect_manager":
			continue
		var manager: StatusEffectManager = actor.get("status_effect_manager")
		if manager != null:
			return manager.can_perform_action(action_name)
	return true
