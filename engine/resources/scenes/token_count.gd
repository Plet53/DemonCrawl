@tool
extends HBoxContainer
class_name TokenCount

# Called when the node enters the scene tree for the first time.
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	if not Codex.token_count_changed.is_connected(update):
		Codex.token_count_changed.connect(update)
	update()


func update():
	$"Label".text = str(Codex.tokens)
