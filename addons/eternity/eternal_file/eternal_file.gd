extends RefCounted
class_name EternalFile

## Helper class to write [Eternal]s to disk.

# ==============================================================================
var _data: Dictionary[String, Dictionary] = {}
# ==============================================================================
signal value_changed(section: String, key: String, value: Variant)
# ==============================================================================

## Removes all values in this file.
func clear() -> void:
	_data.clear()


## Returns a [PackedStringArray] of all [Script]s that have any [Eternal]s.
func get_scripts() -> PackedStringArray:
	var scripts := PackedStringArray()
	for key in _data:
		if _data[key].is_empty():
			continue
		if UserClassDB.class_exists(key):
			scripts.append(key)
	scripts.sort()
	return scripts


## Returns all [Eternal]s saved under the given [param script].
func get_eternals(script: String) -> PackedStringArray:
	if script in _data:
		return PackedStringArray(_data[script].keys())
	return PackedStringArray()


## Returns the saved value of the [Eternal] in the given [param script],
## with the given [param key]. If it is not available, returns [param default],
## or [code]null[/code] if the parameter is omitted.
func get_eternal(script: String, key: String, default: Variant = null) -> Variant:
	if script not in _data or key not in _data[script]:
		return default
	
	return _data[script][key]


## Sets the value of the [Eternal] in the given [param script] with the given
## [param key] to [param value].
func set_eternal(script: String, key: String, value: Variant) -> void:
	if script not in _data:
		_data[script] = {}
	
	_data[script][key] = value
	value_changed.emit(script, key, value)


## Returns whether the given [param key] exists under [param script].
func has_eternal(script: String, key: String) -> bool:
	return script in _data and key in _data[script]
