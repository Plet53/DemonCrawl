extends RefCounted
class_name FileBuffer

# ==============================================================================
var current_line := ""
var line_number := 0
var current_line_newlines := 0
var _file: FileAccess
# ==============================================================================

@warning_ignore("shadowed_variable")
func _init(path: String) -> void:
	_file = FileAccess.open(path, FileAccess.READ)


func get_next() -> String:
	current_line = ""
	while not _file.eof_reached():
		current_line = _file.get_line().strip_edges()
		line_number += 1
		if "#" in current_line:
			current_line = current_line.substr(0, current_line.find("#")).strip_edges()
		if current_line.is_empty():
			continue
		
		if current_line.begins_with("[") and current_line.ends_with("]"):
			return current_line
		
		var value := current_line.trim_prefix(current_line.get_slice("=", 0)).strip_edges().trim_prefix("=").strip_edges()
		assert("=" in current_line, "Invalid line '%s' in file '%s'." % [current_line, _file.get_path()])
		while not _validate_value_string(value):
			var new_line := _file.get_line().strip_edges()
			line_number += 1
			current_line += "\n" + new_line
			value += new_line
		
		return current_line
	
	return current_line


func eof_reached() -> bool:
	return _file.eof_reached()


func get_position() -> int:
	return _file.get_position()


func seek(position: int) -> void:
	var old_position := _file.get_position()
	if position == old_position:
		return
	
	var increment := 1 if position > old_position else -1
	
	var delta := 0
	var pos := old_position
	
	while pos != position:
		pos += increment
		_file.seek(pos)
		
		var byte := _file.get_8()
		
		if byte == 10: # '\n'
			delta += increment
	
	_file.seek(position)
	line_number += delta


func get_path() -> String:
	return _file.get_path()


func get_length() -> int:
	return _file.get_length()


func _validate_value_string(value: String) -> bool:
	value = value.strip_edges()
	
	if value.begins_with("{"):
		return value[-1] == "}"
	if value.begins_with("["):
		return value[-1] == "]"
	if value.begins_with("Array[") or value.begins_with("PackedArray["):
		return Stringifier.get_depth(value, "(", ")") == 0
	return true
