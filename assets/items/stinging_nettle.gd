@tool
extends OmenItem

# ==============================================================================

func _enable() -> void:
	get_inventory().get_effects().item_gain.connect(_on_item_gain)


func _disable() -> void:
	get_inventory().get_effects().item_gain.disconnect(_on_item_gain)


# Reacts to inventory ordering.
func _on_item_gain(_item: Item, should_gain: bool) -> bool:
	if should_gain:
		get_stats().damage(1, self)
	return should_gain
