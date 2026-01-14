@tool
extends Control
class_name QuestComplete

# ==============================================================================

# ==============================================================================
@onready var title = $"Title"
@onready var summary_label = $"SummaryLabel"
@onready var score_label = $"ScoreLabel"
@onready var monster_rect = $"MonsterTaunt/MonsterSprite"
@onready var monster_text = $"MonsterTaunt/MonsterText"
# ==============================================================================

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	title.text = tr("quest-finished.title")
	var quest = Quest.get_current()
	var summary_values := {
		"quest_name": quest.name,
		"color": quest.source_difficulty.color.to_html(false),
		"difficulty_name": quest.source_difficulty.name
	}
	summary_label.text = tr("quest-finished.summary").format(summary_values)
	score_label.text = tr("quest-finished.score").format({"score": quest.get_attributes().score})
	
	var stages : Array[Stage] = quest.get_stages().filter(func (stage):
		return not stage is SpecialStage
	)
	var random_stage = stages[randi() % len(stages)]
	var random_theme = random_stage.get_theme()
	
	monster_rect.texture = random_theme.get_icon("monster", "Cell")
	monster_text.text = load("res://assets/string_tables/monster_taunts.tres").pick_random().format({"monster": random_stage._generate_monster_name().to_upper()})
	
	

# Anim Sequence:
# Quest Complete scrolls in from the side
# Each Line of Summary Fades in and scrolls from just below
# Monster Pops In, expanding and then bouncing back to normal size a few times
# Monster's Taunt scrolls in 1 character per frame

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
# High Score Popup
# New Quest Popup
