extends RefCounted
class_name EternalFileSaver

## Helper class to save values to disk.
##
## [EternalFileSaver] can be used to save game data to disk, to be loaded later with
## [EternalFileLoader]. See [EternalFileLoader] for more information.

# ==============================================================================
var _processing_owner_stack: Array[Object] = []

var _rng := RandomNumberGenerator.new()
var _file: EternalFile
var _resources: Dictionary[Object, int] = {}
# ==============================================================================
signal saved(path: String) ## Emitted when the file is saved to disk.
# ==============================================================================

func _init(file: EternalFile) -> void:
	_file = file


## Clears the stored data on this [EternalFileSaver]. This is automatically called
## in [method save].
func clear() -> void:
	_resources.clear()
	_processing_owner_stack.clear()


## Saves the loaded data to [param path]. If [param safe_mode] is [code]true[/code],
## will encode the file to text first before opening the file. If [code]false[/code],
## will encode to the file directly. Disabling safe mode is faster, but if the program
## crashes while saving, all data will be lost.
func save(path: String, safe_mode: bool = false) -> void:
	var safe_text := ""
	if safe_mode:
		safe_text = encode_to_text()
	
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Could not open file '%s': %s" % [path, error_string(FileAccess.get_open_error())])
		return
	
	if safe_mode:
		file.store_string(safe_text)
	else:
		encode_to_file(file)
	
	file.close()
	
	saved.emit(path)


## Returns owner of the currently processing value.
## [br][br]For example, if we have the
## following file:
## [codeblock]
## [sub_resource script="MyClassA" id="12345678"]
## child = MyClassB()
## [/codeblock]
## Then, in the [code]_export_packed()[/code] method of [code]MyClassB[/code],
## [method get_processing_owner] would return the parent instance of
## [code]MyClassA[/code].
func get_processing_owner() -> Object:
	if _processing_owner_stack.is_empty():
		return null
	return _processing_owner_stack[-1]


func _store_resource(value: Variant) -> Variant:
	var resources: Array[Object] = []
	_prepare_variant(value, resources)
	for resource in resources:
		_resource_get_uid(resource)
	
	return value


func _prepare_resource_list() -> Array[Object]:
	var resources: Array[Object] = []
	
	for script in _file.get_scripts():
		for key in _file.get_eternals(script):
			_store_resource(_file.get_eternal(script, key))
	
	for resource in _resources:
		if resource not in resources:
			resources.append(resource)
	
	var i := 0
	while i < resources.size():
		var resource := resources[i]
		if resource is Resource:
			# handle ext_resource
			if not resource.resource_path.is_empty() and not "::" in resource.resource_path:
				_resource_get_uid(resource)
				i += 1
				continue
		
		for property in resource.get_property_list():
			if resource.has_method("_validate_property"):
				resource._validate_property(property) # this property should be validated but this isn't the case by default
			
			if property.name == "script":
				continue
			if resource.has_method("_export_" + property.name):
				continue
			if property.usage & PROPERTY_USAGE_STORAGE:
				var value = resource.get(property.name)
				if _is_native_default_property(resource, property.name, value):
					continue
				_prepare_variant(value, resources)
		
		if resource is Node and not resource.has_method("_export_children"):
			for child: Node in resource.get_children():
				if child.is_queued_for_deletion():
					continue
				_prepare_variant(child, resources, false)
		
		_resource_get_uid(resource)
		i += 1
	
	assert(resources.all(func(a: Object) -> bool: return resources.count(a) == 1), "Duplicate resource prepared when saving.")
	
	return resources


func _prepare_variant(variant: Variant, resources: Array[Object], allow_packing: bool = true) -> void:
	match typeof(variant):
		TYPE_OBJECT:
			_prepare_object(variant, resources, allow_packing)
		TYPE_ARRAY:
			_prepare_array(variant, resources, allow_packing)
		TYPE_DICTIONARY:
			_prepare_dictionary(variant, resources, allow_packing)


func _prepare_object(object: Object, resources: Array[Object], allow_packing: bool = true) -> void:
	if not is_instance_valid(object):
		return
	
	if allow_packing and _is_object_packable(object):
		_processing_owner_stack.append(object)
		_prepare_variant(object._export_packed(), resources)
		_processing_owner_stack.pop_back()
		return
	
	if object is Node and object.has_method("_export_children"):
		if object not in resources:
			resources.append(object)
		
		_processing_owner_stack.append(object)
		_prepare_variant(object._export_children(), resources)
		_processing_owner_stack.pop_back()
		return
	
	if object is Script and not UserClassDB.script_get_class(object).is_empty():
		return
	
	if object in resources:
		return
	
	resources.append(object)


func _prepare_array(array: Array, resources: Array[Object], allow_packing: bool = true) -> void:
	if allow_packing and _is_packable(array):
		for v in array:
			if v != null:
				_prepare_variant(v._export_packed(), resources)
		return
	
	for v in array:
		_prepare_variant(v, resources, allow_packing)


func _prepare_dictionary(dict: Dictionary, resources: Array[Object], allow_packing: bool = true) -> void:
	for key in dict:
		_prepare_variant(key, resources, allow_packing)
		_prepare_variant(dict[key], resources, allow_packing)


func _is_object_packable(object: Object) -> bool:
	if object.has_method("_export_packed_enabled") and not object._export_packed_enabled():
		return false
	return object.has_method("_export_packed")


func _is_packable(value: Variant) -> bool:
	if not value is Array or not value.is_typed():
		return false
	
	var script := value.get_typed_script() as Script
	if not script:
		return false
	
	for method in script.get_script_method_list():
		if method.flags & METHOD_FLAG_STATIC:
			continue
		if method.name == "_export_packed":
			return true
	return false


func _validate_value_string(value: String) -> bool:
	value = value.strip_edges()
	
	if value.begins_with("{"):
		return value[-1] == "}"
	if value.begins_with("["):
		return value[-1] == "]"
	if value.begins_with("Array[") or value.begins_with("PackedArray["):
		return Stringifier.get_depth(value, "(", ")") == 0
	return true


## Encodes all saved data into a [String].
func encode_to_text() -> String:
	var result := ""
	var stream := encode_to_stream()
	while true:
		var value = stream.get_next()
		if stream.is_finished():
			return result
		result += value
	return result


func encode_to_file(file: FileAccess) -> void:
	var stream := encode_to_stream()
	while true:
		var value = stream.get_next()
		if stream.is_finished():
			return
		file.store_string(value)


func encode_to_stream() -> ValueStream:
	var stream := ValueStream.new()
	_stream_encode(stream)
	return stream


func _stream_encode(stream: ValueStream) -> void:
	await stream.start()
	
	var resources := _prepare_resource_list()
	
	var ext_resources: Array[Resource] = []
	var sub_resources: Array[Resource] = []
	var nodes: Array[Node] = []
	for resource in resources:
		if resource is Resource:
			if resource.resource_path.is_empty() or "::" in resource.resource_path:
				sub_resources.append(resource)
			else:
				ext_resources.append(resource)
		elif resource is Node:
			nodes.append(resource)
	
	ext_resources.sort_custom(func(a: Resource, b: Resource) -> bool: return a.resource_path < b.resource_path)
	
	for ext_resource in ext_resources:
		await stream.step("[ext_resource path=\"%s\" id=\"%s\"]\n" % [
			ext_resource.resource_path,
			_stringify_uid(_resource_get_uid(ext_resource)),
		])
	if not ext_resources.is_empty():
		await stream.step("\n")
	for sub_resource in sub_resources:
		_processing_owner_stack.append(sub_resource)
		
		var script := sub_resource.get_script() as Script
		if script:
			await stream.step("[sub_resource script=\"%s\" id=\"%s\"]\n" % [
				UserClassDB.script_get_identifier(script),
				_stringify_uid(_resource_get_uid(sub_resource))
			])
		else:
			await stream.step("[sub_resource class=\"%s\" id=\"%s\"]\n" % [
				sub_resource.get_class(),
				_stringify_uid(_resource_get_uid(sub_resource))
			])
		
		for property in sub_resource.get_property_list():
			if property.name == "script":
				continue
			if property.name == "resource_local_to_scene" and sub_resource.get(property.name) == false:
				continue
			if property.name == "resource_name" and sub_resource.get(property.name) == "":
				continue
			if property.usage & PROPERTY_USAGE_STORAGE:
				var value = sub_resource[property.name]
				if _is_native_default_property(sub_resource, property.name, value):
					continue
				await stream.step("%s = %s\n" % [property.name, _serialize_value(value)])
		
		await stream.step("\n")
		
		_processing_owner_stack.pop_back()
	
	for node in nodes:
		_processing_owner_stack.append(node)
		
		var properties: Dictionary[String, Variant] = {}
		
		if "@" not in node.name:
			properties.name = String(node.name)
		
		var script := node.get_script() as Script
		if script:
			properties.script = String(UserClassDB.script_get_identifier(script))
		else:
			properties.class = node.get_class()
		
		var parent := node.get_parent()
		if parent and parent in nodes:
			properties.parent = parent
		
		properties.id = _stringify_uid(_resource_get_uid(node))
		
		await stream.step(_serialize_header("node", properties))
		
		if node.has_method("_export_children"):
			var children = node._export_children()
			if children is not Array or not children.is_empty():
				await stream.step("*children = %s\n" % _serialize_value(children))
		
		for property in node.get_property_list():
			if property.name == "script":
				continue
			if property.usage & PROPERTY_USAGE_STORAGE:
				var value = node[property.name]
				if _is_native_default_property(node, property.name, value):
					continue
				await stream.step("%s = %s\n" % [property.name, _serialize_value(value)])
		
		await stream.step("\n")
		
		_processing_owner_stack.pop_back()
	
	for script in _file.get_scripts():
		_processing_owner_stack.append(UserClassDB.class_get_script(script))
		
		await stream.step("[%s]\n" % script)
		for key in _file.get_eternals(script):
			var value := _serialize_value(_file.get_eternal(script, key))
			await stream.step("%s = %s\n" % [key, value])
		
		await stream.step("\n")
		
		_processing_owner_stack.pop_back()
	
	assert(_processing_owner_stack.is_empty(), "Processing stack did not get cleared.")
	stream.finish()


func _serialize_header(header_name: String, properties: Dictionary[String, Variant]) -> String:
	return "[" + header_name + " " + " ".join(properties.keys().map(func(key: String) -> String:
		return key + "=" + _serialize_value(properties[key], false)
	)) + "]\n"


func _serialize_value(value: Variant, allow_packing: bool = true) -> String:
	if allow_packing and value is Object and _is_object_packable(value):
		var script := UserClassDB.script_get_identifier(value.get_script())
		var r = value._export_packed()
		if r is Array:
			return "%s(%s)" % [
				script,
				", ".join(r.map(_serialize_value))
			]
		return "%s(%s)" % [script, r]
	
	if value is Script:
		var name := UserClassDB.script_get_class(value)
		if not name.is_empty():
			return name
	if value is Resource:
		return "Resource(\"%s\")" % _stringify_uid(_resource_get_uid(value))
	if value is Node:
		return "Node(\"%s\")" % _stringify_uid(_resource_get_uid(value))
	if value is Array:
		if not value.is_typed():
			return "[" + ", ".join(value.map(_serialize_value.bind(allow_packing))) + "]"
		
		var type := value.get_typed_builtin() as Variant.Type
		if type != TYPE_OBJECT:
			return "Array[%s]([%s])" % [
				type_string(type),
				", ".join(value.map(_serialize_value.bind(allow_packing)))
			]
		
		var script := value.get_typed_script() as Script
		if not script:
			return "Array[%s]([%s])" % [
				value.get_typed_class_name(),
				", ".join(value.map(_serialize_value.bind(allow_packing)))
			]
		
		var script_id := UserClassDB.script_get_identifier(script)
		
		for method in UserClassDB.class_get_method_list(script_id):
			if method.flags & METHOD_FLAG_STATIC:
				continue
			if method.name == "_export_packed":
				return "PackedArray[%s](%s)" % [
					script_id,
					", ".join(value.map(func(v: Object) -> String:
						var pack := _pack(v)
						if v.get_script() != script:
							if pack.match("(*)"):
								pack = UserClassDB.script_get_identifier(v.get_script()) + pack
							else:
								pack = "%s(%s)" % [UserClassDB.script_get_identifier(v.get_script()), pack]
						return pack\
					))
				]
		
		return "Array[%s]([%s])" % [
			script_id,
			", ".join(value.map(_serialize_value.bind(allow_packing)))
		]
	if value is Dictionary:
		if not value.is_typed():
			if value.is_empty():
				return "{}"
			
			return "{\n\t" + ",\n\t".join(value.keys().map(func(key: Variant) -> String:
				return _serialize_value(key, allow_packing) + ": " + _serialize_value(value[key], allow_packing)
			)) + "\n}"
		
		var key_type_name := _get_type_name(value.get_typed_key_builtin(), value.get_typed_key_class_name(), value.get_typed_key_script())
		var value_type_name := _get_type_name(value.get_typed_value_builtin(), value.get_typed_value_class_name(), value.get_typed_value_script())
		
		if value.is_empty():
			return "Dictionary[%s, %s]({})" % [key_type_name, value_type_name]
		
		return "Dictionary[%s, %s]({\n\t" % [key_type_name, value_type_name] + ",\n\t".join(value.keys().map(func(key: Variant) -> String:
			return _serialize_value(key, allow_packing) + ": " + _serialize_value(value[key], allow_packing)
		)) + "\n})"
	
	return Stringifier.stringify(value)


func _get_type_name(type: Variant.Type, type_class_name: StringName, type_script: Script) -> String:
	if type != TYPE_OBJECT:
		return type_string(type)
	
	if type_script == null:
		assert(ClassDB.class_exists(type_class_name), "Unknown type name '%s' or invalid script." % type_class_name)
		return type_class_name
	
	return UserClassDB.script_get_identifier(type_script)


func _pack(value: Object) -> String:
	if value == null:
		return "<null>"
	
	var pack = value._export_packed()
	if not pack is Array:
		return _serialize_value(pack)
	
	if pack.is_empty():
		return "()"
	if pack.size() == 1:
		return _serialize_value(pack[0])
	
	return "(%s)" % [
		", ".join(pack.map(_serialize_value))
	]


func _is_native_default_property(object: Object, property: StringName, value: Variant) -> bool:
	if is_same(ClassDB.class_get_property(object, property), null):
		return false
	return value == ClassDB.class_get_property_default_value(object.get_class(), property)


func _resource_get_uid(resource: Object) -> int:
	if resource not in _resources:
		var id := _generate_unique_id()
		_resources[resource] = id
		return id
	return _resources[resource]


func _generate_unique_id() -> int:
	var uid := _rng.randi()
	while uid in _resources.values():
		uid = _rng.randi()
	return uid


func _stringify_uid(uid: int) -> String:
	return "%08x" % uid


class ValueStream:
	var _value: Variant = null
	var _finished := false : get = is_finished
	signal _queried()
	
	func get_next() -> Variant:
		_queried.emit()
		if _finished:
			return null
		return _value
	
	func step(next: Variant) -> void:
		_value = next
		await _queried
	
	func start() -> void:
		_finished = false
		await _queried
	
	func finish() -> void:
		_finished = true
	
	func is_finished() -> bool:
		return _finished
