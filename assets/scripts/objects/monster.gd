@tool
extends CellObject
class_name Monster

## A monster that attacks the player when revealed.

# ==============================================================================
@export var monster_name := ""
# ==============================================================================

func _get_name_id() -> String:
	return "object.monster"


func _spawn() -> void:
	monster_name = get_origin_stage().generate_monster_name()


func _get_texture() -> Texture2D:
	return get_theme_icon("monster").duplicate()


func _get_source() -> Texture2D:
	return (get_theme_icon("monster") as TextureSequence).get_texture(0)


func _reveal_active() -> void:
	EffectManager.propagate(get_stage_instance().get_cell_effects().mistake_made, get_cell())
	Quest.get_current().get_stats().damage(get_origin_stage().roll_power(), self)


func _get_annotation_title() -> String:
	return monster_name


func _aura_apply() -> void:
	if get_cell().get_aura() is Burning:
		kill()


func _contribute_value() -> int:
	return 1
