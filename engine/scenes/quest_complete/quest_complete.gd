@tool
extends Control
class_name QuestComplete

# ==============================================================================
@onready var summary_label = $"SummaryLabel"
@onready var score_label = $"ScoreLabel"
@onready var monster_sprite = $"MonsterTaunt/MonsterBox/MonsterSprite"
@onready var monster_taunt = $"MonsterTaunt/MonsterText"
@onready var animation_player = $"QuestCompleteAP"
# ==============================================================================

func _ready() -> void:
	var quest := Quest.get_current()
	var summary_values := {
		"quest_name": tr(quest.source_file.name).to_upper(),
		"color": quest.source_difficulty.color.to_html(false),
		"difficulty_name": tr(quest.source_difficulty.name).to_upper()
	}
	summary_label.text = tr("quest-finished.summary").format(summary_values)
	score_label.text = tr("quest-finished.score").format({"score": quest.get_attributes().score})
	
	var stages: Array[StageBase] = quest.get_stages().filter(func (stage):
		return not stage is SpecialStage
	)
	var random_base := stages[randi() % len(stages)]
	var random_texture = random_base.file.monster_texture
	var random_sprite = AnimatedTextureSequence.new()
	random_sprite.atlas = random_texture
	random_sprite.duration = 1.0
	random_sprite.size = Vector2i.ONE * 16
	monster_taunt.text = load("res://assets/string_tables/monster_taunts.tres").pick_random().format({"monster": random_base.generate_monster_name().to_upper()})
	monster_taunt.visible_characters = 0
	monster_sprite.texture = random_sprite
	
	animation_player.play(&"quest_finished")


func animate_monster_taunt():
	var tween_animation = monster_taunt.create_tween()
	tween_animation.tween_property(monster_taunt, "visible_characters", len(monster_taunt.text), len(monster_taunt.text) / 60.0)


func _on_done_pressed():
	Quest.get_current().finish()
