extends Control
class_name HighScorePopup

# ==============================================================================
const SCENE := "res://engine/resources/singletons/high_score_popup.tscn"
# ==============================================================================

static func show_score(score: int) -> void:
	var instance: HighScorePopup = load(SCENE).instantiate()
	instance.get_node(^"ContentsAnchor_MarginContainer#VBoxContainer/Label2").text %= {"score": score}
	await DCPopup.popup_show_instance(instance)
	instance.queue_free()
