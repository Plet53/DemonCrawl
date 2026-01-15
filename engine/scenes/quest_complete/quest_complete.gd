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
	
	# Anim Sequence:
	var tween_animation = create_tween()
	
	# Quest Complete scrolls in from the left
	var title_final_pos = title.position.x
	title.position.x -= 300
	tween_animation.tween_property(title, "position:x", title_final_pos, 1.0).set_ease(Tween.EASE_OUT)
	
	# Each Line of Summary Fades in and scrolls from just below
	for label in [summary_label, score_label]:
		var label_final_pos = label.position.y
		label.position.y -= 64
		label.modulate.a = 0
		tween_animation.tween_property(label, "position:y", label_final_pos, 1.0)
		tween_animation.parallel().tween_property(label, "modulate:a", 255, 1.0)
	
	# Monster Pops In, expanding to its full size elastically
	var final_monster_scale = monster_sprite.scale
	monster_sprite.scale = Vector2.ZERO
	tween_animation.tween_property(monster_sprite, "scale", final_monster_scale, 1.0).set_trans(Tween.TRANS_ELASTIC)
	# Monster's Taunt scrolls in 1 character per frame
	tween_animation.parallel().tween_property(monster_taunt, "visible_characters", len(monster_taunt.text), len(monster_taunt.text) / 60.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
# High Score Popup
# New Quest Popup
