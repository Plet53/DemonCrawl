@tool
extends Control
class_name QuestComplete

# ==============================================================================

# ==============================================================================
@onready var title = $"Title"
@onready var summary_label = $"SummaryLabel"
@onready var score_label = $"ScoreLabel"
@onready var monster_sprite = $"MonsterTaunt/MonsterBox/MonsterSprite"
@onready var monster_taunt = $"MonsterTaunt/MonsterText"
@onready var animation_player = %"AnimationPlayer"
# ==============================================================================

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var quest := Quest.get_current()
	var summary_values := {
		"quest_name": quest.name,
		"color": quest.source_difficulty.color.to_html(false),
		"difficulty_name": quest.source_difficulty.name
	}
	summary_label.text %= summary_values
	score_label.text %= {"score": quest.get_attributes().score}
	
	var stages: Array[StageBase] = quest.get_stages().filter(func (stage):
		return not stage is SpecialStage
	)
	var random_base := stages[randi() % len(stages)]
	monster_taunt.text = load("res://assets/string_tables/monster_taunts.tres").pick_random().format({"monster": random_base.generate_monster_name().to_upper()})
	monster_taunt.visible_characters = 0
	var random_theme = random_base.get_instance().get_scene().get_theme()
	monster_sprite.texture = random_theme.get_icon("monster", "Cell")
	
	animation_player.play(&"quest_finished")


func animate_monster_taunt():
	var tween_animation = monster_taunt.create_tween()
	tween_animation.tween_property(monster_taunt, "visible_characters", len(monster_taunt.text), len(monster_taunt.text) / 60.0)
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
# High Score Popup
# New Quest Popup
