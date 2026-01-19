extends Control
class_name QuestUnlockedPopup

# ==============================================================================
const SCENE := "res://engine/resources/singletons/quest_unlocked_popup.tscn"
# ==============================================================================

static func show_quest_unlock(quest: String) -> void:
	var instance: QuestUnlockedPopup = load(SCENE).instantiate()
	instance.get_node(^"ContentsAnchor_MarginContainer#VBoxContainer/Label2").text %= quest.to_upper()
	await DCPopup.popup_show_instance(instance)
	instance.queue_free()
