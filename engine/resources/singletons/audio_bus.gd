extends Node
class_name AudioBus

# ==============================================================================
@onready var _music_player: AudioStreamPlayer = %MusicPlayer
@onready var _effect_player: AudioStreamPlayer = %EffectPlayer
@onready var _ambience_a_player: AudioStreamPlayer = %AmbienceAPlayer
@onready var _ambience_b_player: AudioStreamPlayer = %AmbienceBPlayer
# ==============================================================================
static var _instance: AudioBus
# ==============================================================================

func _ready() -> void:
	_instance = self


static func set_volumes(volumes: Array[float]) -> void:
	_instance._music_player.volume_linear = volumes[0]
	_instance._effect_player.volume_linear = volumes[1]
	_instance._ambience_a_player.volume_linear = volumes[2]
	_instance._ambience_b_player.volume_linear = volumes[2]


static func play_music(stream: AudioStream) -> void:
	_instance._music_player.stream = stream
	_instance._music_player.play()


static func stop_music() -> void:
	_instance._music_player.stop()


static func play_effect(stream: AudioStream) -> void:
	_instance._effect_player.stream = stream
	_instance._effect_player.play()


static func play_ambiance_a(stream: AudioStream) -> void:
	_instance._ambience_a_player.stream = stream
	_instance._ambience_a_player.play()


static func play_ambiance_b(stream: AudioStream) -> void:
	_instance._ambience_b_player.stream = stream
	_instance._ambience_b_player.play()


static func stop_ambience() -> void:
	_instance._ambience_a_player.stop()
	_instance._ambience_b_player.stop()
