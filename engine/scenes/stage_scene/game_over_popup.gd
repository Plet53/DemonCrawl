extends CanvasLayer
class_name GameOverPopup

# ==============================================================================
@onready var _cause_label: Label = %CauseLabel
@onready var _animation_player = %AnimationPlayer
# ==============================================================================
@export var cause: String = "":
	set(value):
		cause = value
# ==============================================================================

func _ready() -> void:
	hide()


func popup() -> void:
	show()
	
	var cause_string: String = load("res://assets/string_tables/game_over.tres").pick_random()
	if cause_string.contains("{{cause}}"):
		cause_string = cause_string.format({"cause": cause.to_upper()})
	
	_cause_label.text = cause_string
	
	_animation_player.play("popup_show")
	
	await _animation_player.animation_finished


func _on_view_board_pressed() -> void:
	_animation_player.play("popup_hide")
	
	await _animation_player.animation_finished
	
	get_parent().show_menu_button()
	hide()


func _on_restart_pressed() -> void:
	Quest.get_current().restart()


func _on_return_to_menu_pressed() -> void:
	_animation_player.play("popup_hide")
	
	await _animation_player.animation_finished
	
	hide()
	
	Quest.get_current().lose()
