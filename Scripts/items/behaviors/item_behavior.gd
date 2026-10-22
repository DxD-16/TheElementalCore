class_name ItemBehavior
extends Resource

func use(_user: Node, _item: ItemInstance) -> bool:
	push_error("[ItemBehavior] Subclasses must implement use()")
	return false
