@tool
extends OmenItem

# ==============================================================================

# Reacts to inventory ordering.
func _on_item_gain(_item: Item, should_gain: bool) -> bool:
	if should_gain:
		get_stats().damage(1, self)
	return should_gain
