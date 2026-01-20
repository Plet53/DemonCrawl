extends Control
class_name QuestUnlockedPopup

# ==============================================================================
const SCENE := "res://engine/resources/singletons/quest_unlocked_popup.tscn"
# ==============================================================================

func show_quest_unlock(quest: String, locked: bool) -> void:
	var instance: QuestUnlockedPopup = load(SCENE).instantiate()
	instance.get_node(^"ContentsAnchor_MarginContainer#VBoxContainer/Label2").text = \
		tr("popup.new-quest." + ("locked" if locked else "unlocked")).format({"quest_name": tr(quest).to_upper()})
	await DCPopup.popup_show_instance(instance)
	instance.queue_free()
