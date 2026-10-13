class_name ActionGate
extends RefCounted

func can_perform_action(actor: Node, action_name: String) -> bool:
	if actor == null:
		return false
	if action_name == "" or action_name == "none":
		return false

	if actor.has_method("has_status") and actor.has_status("stun"):
		return false
	if actor.has_method("has_status") and actor.has_status("freeze"):
		return false
	if actor.has_method("is_controls_locked") and actor.is_controls_locked():
		return false
	if actor.get("is_dead") == true:
		return false

	if action_name == "attack":
		return true
	if action_name == "jump":
		return true
	if action_name == "dash":
		return true
	if action_name == "block":
		return true
	return true
