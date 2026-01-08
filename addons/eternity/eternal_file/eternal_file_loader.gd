extends RefCounted
class_name EternalFileLoader

## Helper class to load values from disk.
##
## [EternalFileLoader] can be used to load a file saved by [EternalFileSaver].
## It follows similar file structure as a [Resource] or [PackedScene], but with
## added functionality, such as allowing subclasses (defined with [code]class
## MyClass:[/code] instead of [code]class_name[/code]) and custom constructors
## to reduce the size of the file.
## [br][br]Example on how to use [EternalFileLoader]:
## [codeblock]
## func save_file(file, path):
##     var saver = EternalFileSaver.new(file)
##     saver.save(path)
##
## func load_file(path):
##     var loader = EternalFileLoader.new()
##     return loader.load(path)
## [/codeblock]
## [br][b]Note:[/b] [EternalFileLoader] is intended to be used with [Eternity],
## and can easily be misused otherwise.

# ==============================================================================
static var TYPE_NAME_LIST := range(TYPE_MAX).map(func(t: Variant.Type) -> String: return type_string(t))
# ==============================================================================
var _processing_owner_stack: Array[Object] = []

var _file: EternalFile
var _resources: Dictionary[int, Object] = {}
# ==============================================================================
## Emitted when a file is loaded. [br][br][b]Note:[/b] Although the file's properties
## will be loaded into memory at this point, they may not have been assigned to their
## respective [Eternal]s yet.
signal loaded(path: String)

signal _resource_loaded(id: int)
# ==============================================================================

## Clears the stored data on this [EternalFileLoader]. This is automatically called
## in [method load].
func clear() -> void:
	_resources.clear()
	_processing_owner_stack.clear()


## Loads the file at the given [param path].
func load(path: String) -> EternalFile:
	if not FileAccess.file_exists(path):
		return EternalFile.new()
	
	var buffer := FileBuffer.new(path)
	_file = EternalFile.new()
	_parse_ini(buffer)
	loaded.emit(path)
	return _file


## Returns owner of the currently processing value.
## [br][br]For example, if we have the
## following file:
## [codeblock]
## [sub_resource script="MyClassA" id="12345678"]
## child = MyClassB()
## [/codeblock]
## Then, in the constructor of [code]MyClassB[/code], [method get_processing_owner]
## would return the parent instance of [code]MyClassA[/code].
func get_processing_owner() -> Object:
	if _processing_owner_stack.is_empty():
		return null
	return _processing_owner_stack[-1]


func _parse_ini(buffer: FileBuffer) -> void:
	clear()
	
	_processing_owner_stack.clear()
	
	if buffer.get_length() == 0:
		return
	
	var current_section := ""
	while not buffer.eof_reached():
		var line := buffer.get_next()
		
		if line.begins_with("[") and line.ends_with("]"):
			current_section = _parse_header(line, buffer)
			continue
		
		if not current_section.is_empty():
			_parse_line(line, current_section, buffer.get_path())
		elif _processing_owner_stack[-1] != null:
			_parse_line(line, _processing_owner_stack[-1], buffer.get_path())
	
	_processing_owner_stack.pop_back()
	assert(_processing_owner_stack.is_empty(), "Processing stack did not get cleared.")
	
	_resource_loaded.emit(-1)


func _parse_header(header: String, buffer: FileBuffer) -> String:
	header = header.substr(1, header.length() - 2).strip_edges()
	
	if header.begins_with("ext_resource "):
		_parse_header_ext_resource(header, buffer)
		return ""
	
	if header.begins_with("sub_resource "):
		_parse_header_sub_resource(header, buffer)
		return ""
	
	if header.begins_with("node "):
		_parse_header_node(header, buffer)
		return ""
	
	_processing_owner_stack.pop_back()
	_processing_owner_stack.append(UserClassDB.class_get_script(header))
	return header


func _parse_header_ext_resource(header: String, buffer: FileBuffer) -> void:
	var id := header.get_slice("id=\"", 1).get_slice("\"", 0).hex_to_int()
	assert(id not in _resources, "Duplicate ID found in the file at '%s', at line %d." % [buffer.get_path(), buffer.line_number])
	
	var path := header.get_slice("path=\"", 1).get_slice("\"", 0)
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource not in _resources.values():
			_resources[id] = resource
		
		_processing_owner_stack.pop_back()
		_processing_owner_stack.append(resource)
	else:
		var resource := MissingExtResource.new()
		resource.path = path
		_resources[id] = resource
		
		_processing_owner_stack.pop_back()
		_processing_owner_stack.append(resource)


func _parse_header_sub_resource(header: String, buffer: FileBuffer) -> void:
	var id := header.get_slice("id=\"", 1).get_slice("\"", 0).hex_to_int()
	assert(id not in _resources, "Duplicate ID found in the file at '%s', at line %d." % [buffer.get_path(), buffer.line_number])
	
	if header.match("* script=\"*\"*"):
		var script_name := header.get_slice("script=\"", 1).get_slice("\"", 0)
		if not UserClassDB.class_exists(script_name):
			push_error("Could not instantiate an object with class name '%s'." % script_name)
		
			_processing_owner_stack.pop_back()
			_processing_owner_stack.append(null)
			
			return
		
		var instance := UserClassDB.instantiate(script_name)
		assert(instance is Resource, "A sub_resource script must use a Resource-extending Script, but %s was found." % (instance.get_class() if instance else "Nil"))
		_resources[id] = instance
		_resource_loaded.emit(id)
		
		_processing_owner_stack.pop_back()
		_processing_owner_stack.append(instance)
		
		return
	
	if header.match("* class=\"*\"*"):
		var instance: Object = ClassDB.instantiate(header.get_slice("class=\"", 1).get_slice("\"", 0))
		assert(instance is Resource, "A sub_resource object must use a Resource-extending class, but %s was found." % (instance.get_class() if instance else "Nil"))
		_resources[id] = instance
		_resource_loaded.emit(id)
		
		_processing_owner_stack.pop_back()
		_processing_owner_stack.append(instance)


func _parse_header_node(header: String, buffer: FileBuffer) -> void:
	var id := header.get_slice("id=\"", 1).get_slice("\"", 0).hex_to_int()
	assert(id not in _resources, "Duplicate ID found in the file at '%s', at line %d." % [buffer.get_path(), buffer.line_number])
	var node: Node
	if header.match("* script=\"*\"*"):
		var script_name := header.get_slice("script=\"", 1).get_slice("\"", 0)
		if not UserClassDB.class_exists(script_name):
			push_error("Could not instantiate an object with class name '%s'." % script_name)
			
			_processing_owner_stack.pop_back()
			_processing_owner_stack.append(null)
			return
		
		var instance := UserClassDB.instantiate(script_name)
		assert(instance is Node, "A node script must use a Node-extending Script, but %s was found." % (instance.get_class() if instance else "Nil"))
		_resources[id] = instance
		_resource_loaded.emit(id)
		
		node = instance
		
		_processing_owner_stack.pop_back()
		_processing_owner_stack.append(instance)
	elif header.match("* class=\"*\"*"):
		var instance: Object = ClassDB.instantiate(header.get_slice("class=\"", 1).get_slice("\"", 0))
		assert(instance is Node, "A node object must use a Node-extending class, but %s was found." % (instance.get_class() if instance else "Nil"))
		_resources[id] = instance
		_resource_loaded.emit(id)
		
		node = instance
		
		_processing_owner_stack.pop_back()
		_processing_owner_stack.append(instance)
	
	if header.match("* parent=*"):
		(func() -> void:
			var parent_string := header.get_slice("parent=", 1).get_slice(" ", 0).get_slice("]", 0)
			var parent = _parse_value(parent_string)
			parent = await _await_resource(parent)
			
			if not parent:
				# _await_resource() failed; it already printed an error
				# we free the child because otherwise it is unexpectedly orphaned
				
				# this case shouldn't happen normally but it can if the user manually
				# deleted the parent node from the file; they probably want the
				# entire ancestry deleted
				
				# it can also happen if the parent is from a previous update and
				# cannot be loaded anymore
				node.queue_free()
				return
			
			assert(parent is Node, "Cannot add a Node as a child of a non-Node.")
			parent.add_child(node)
		).call()
	
	if header.match("* name=\"*\""):
		node.name = header.get_slice("name=\"", 1).get_slice("\"", 0)


func _parse_line(line: String, owner: Variant, file_path: String) -> void:
	line = line.substr(0, line.find("#")).strip_edges()
	if line.is_empty():
		return
	
	var key := line.get_slice("=", 0).strip_edges()
	var value := line.trim_prefix(key).strip_edges().trim_prefix("=").strip_edges()
	assert("=" in line, "Invalid line '%s' in file '%s'." % [line, file_path])
	
	_set_variant(owner, key, await _await_resource(_parse_value(value)))


func _set_variant(variant: Variant, key: Variant, value: Variant) -> void:
	match typeof(variant):
		TYPE_STRING, TYPE_STRING_NAME:
			if key is String or key is StringName:
				_file.set_eternal(variant, key, value)
		TYPE_DICTIONARY:
			variant[key] = value
		TYPE_OBJECT:
			if key is String or key is StringName:
				if key == "*children":
					assert(variant is Node, "Cannot add children to a non-Node.")
					assert(value is Array, "Cannot unpack children; the value must be an Array.")
					for i in value:
						assert(i is Node, "Cannot add child: Node expected, but %s was found." % Stringifier.get_type_string(i))
						variant.add_child(i)
					return
				
				variant.set(key, value)


func _await_resource(resource: Variant) -> Variant:
	if not resource is PendingResourceBase:
		return resource
	
	var owner := _processing_owner_stack[-1]
	
	while not resource.is_ready(_resources):
		await _resource_loaded
		
		if _processing_owner_stack.is_empty():
			Debug.log_error("Could not load a pending resource of type %s. Invalid id?" % Stringifier.get_type_string(resource))
			return (resource as PendingResourceBase).create(_resources)
	
	var added_owner := false
	if _processing_owner_stack[-1] != owner:
		_processing_owner_stack.append(owner)
		added_owner = true
	
	var value = resource.create(_resources)
	
	if added_owner:
		_processing_owner_stack.pop_back()
	
	return value


func _parse_value(value: String) -> Variant:
	value = value.strip_edges()
	
	if value == "<null>":
		return null
	if value.is_valid_int():
		return value.to_int()
	if value.is_valid_float():
		return value.to_float()
	if value == "true":
		return true
	if value == "false":
		return false
	if value == "null":
		return null
	if value.begins_with("\"") and value.ends_with("\""):
		return value.substr(1, value.length() - 2)
	
	if value.begins_with("Resource(\"") and value.ends_with("\")"):
		var id := value.get_slice("\"", 1).hex_to_int()
		if id in _resources:
			return _resources[id]
		return PendingResource.new(id)
	
	if value.begins_with("Node(\"") and value.ends_with("\")"):
		var id := value.get_slice("\"", 1).hex_to_int()
		if id in _resources:
			return _resources[id]
		return PendingResource.new(id)
	
	if value.match("[*]"):
		return _parse_array(value)
	
	if value.match("Array[*]([*])"):
		return _parse_typed_array(value)
	
	if value.match("PackedArray[*](*)"):
		return _parse_packed_array(value)
	
	if value.match("*(*)") and UserClassDB.class_exists(value.get_slice("(", 0)):
		return _parse_constructor(value)
	
	if value.match("{*}"):
		return _parse_dict(value)
	
	if value.match("Dictionary[*,*]({*})"):
		return _parse_typed_dict(value)
	
	if UserClassDB.class_exists(value):
		return UserClassDB.class_get_script(value)
	
	return Stringifier.parse(value)


func _parse_array(value: String) -> Variant:
	var values_string := Stringifier.split_ignoring_nested(value.trim_prefix("[").trim_suffix("]"), ",")
	var values := []
	var is_pending := false
	for s in values_string:
		s = s.strip_edges()
		if s.is_empty():
			continue
		var v = _parse_value(s)
		if v is PendingResourceBase:
			is_pending = true
		elif v is MissingExtResource:
			continue
		values.append(v)
	if is_pending:
		return UntypedPendingResourceArray.new(values)
	return Array(values_string).map(_parse_value)


func _parse_typed_array(value: String) -> Variant:
	var type_name := value.trim_prefix("Array[").get_slice("]", 0)
	
	if ClassDB.class_exists(type_name):
		var values := Array(value.split(",")).map(_parse_value)
		if values.any(func(a: Variant) -> bool: return a is PendingResourceBase):
			return TypedPendingResourceArray.new(values, Array([], TYPE_OBJECT, type_name, null))
		return Array(values, TYPE_OBJECT, type_name, null)
	
	if UserClassDB.class_exists(type_name):
		var script := UserClassDB.class_get_script(type_name)
		var values_string := value.substr(9 + type_name.length()).trim_suffix("])")
		var values := []
		var is_pending := false
		for s in Stringifier.split_ignoring_nested(values_string, ","):
			s = s.strip_edges()
			if s.is_empty():
				continue
			
			var v = _parse_value(s)
			if v is PendingResourceBase:
				is_pending = true
			elif v is MissingExtResource:
				continue
			
			values.append(v)
		
		if is_pending:
			return TypedPendingResourceArray.new(values, Array([], TYPE_OBJECT, script.get_instance_base_type(), script))
		
		return Array(values, TYPE_OBJECT, script.get_instance_base_type(), script)
	
	var type := _get_type_int(type_name)
	assert(type != -1, "Invalid class name in value '%s'." % value)
	return Array(Array(value.substr(9 + type_name.length()).trim_suffix("])").split(",")).map(_parse_value), type, "", null)


func _parse_packed_array(value: String) -> Variant:
	var script_name := value.trim_prefix("PackedArray[").get_slice("]", 0)
	assert(UserClassDB.class_exists(script_name), "Invalid PackedArray of type '%s': Expected class name.")
	
	var script := UserClassDB.class_get_script(script_name)
	
	var values := []
	var is_pending := false
	for s in Stringifier.split_ignoring_nested(value.trim_prefix("PackedArray[" + script_name + "]" + "(").trim_suffix(")"), ","):
		s = s.strip_edges()
		
		var s_script_name: String
		if not s.begins_with("(") and s.match("*(*)"):
			s_script_name = s.get_slice("(", 0)
		else:
			s_script_name = script_name
		
		var constructor := Constructor.new(s_script_name)
		
		s = s.trim_prefix(s_script_name).trim_prefix("(").trim_suffix(")").strip_edges()
		
		if s == "<null>":
			values.append(null)
			continue
		
		var arg_strings := Stringifier.split_ignoring_nested(s, ",")
		
		var instance := constructor.construct(Array(arg_strings).map(_parse_value))
		if instance is PendingResourceBase:
			is_pending = true
		values.append(instance)
	
	if is_pending:
		return TypedPendingResourceArray.new(values, Array([], TYPE_OBJECT, script.get_instance_base_type(), script))
	
	return Array(values, TYPE_OBJECT, script.get_instance_base_type(), script)


func _parse_constructor(value: String) -> Object:
	var script_name := value.get_slice("(", 0).trim_suffix(")")
	
	var args := _parse_value_list(value.trim_prefix(script_name + "(").trim_suffix(")"))
	
	return Constructor.new(script_name).construct(args)


func _parse_dict(value: String) -> Variant:
	var dict := {}
	var pairs := Stringifier.split_ignoring_nested(value.trim_prefix("{").trim_suffix("}"), ",")
	var is_pending := false
	for pair in pairs:
		pair = pair.strip_edges()
		if pair.is_empty():
			continue
		
		var key_value := Stringifier.split_ignoring_nested(pair, ":")
		var key = _parse_value(key_value[0])
		var parsed_value = _parse_value(key_value[1])
		
		if key is PendingResourceBase or parsed_value is PendingResourceBase:
			is_pending = true
		elif key is MissingExtResource or parsed_value is MissingExtResource:
			continue
		
		dict[key] = parsed_value
	
	if is_pending:
		return UntypedPendingResourceDictionary.new(dict)
	return dict


func _parse_typed_dict(value: String) -> Variant:
	var type_name_pair := value.trim_prefix("Dictionary[").get_slice("]", 0)
	var key_type_name := type_name_pair.get_slice(",", 0).strip_edges()
	var value_type_name := type_name_pair.get_slice(",", 1).strip_edges()
	
	var content_string := value.substr(value.find("]") + 1).trim_prefix("(").trim_suffix(")")
	var content = _parse_dict(content_string)
	
	var dict: Dictionary
	var is_pending: bool
	if content is UntypedPendingResourceDictionary:
		dict = content.dict
		is_pending = true
	else:
		dict = content
		is_pending = false
	
	if is_pending:
		return TypedPendingResourceDictionary.new(dict, Dictionary({},
			_get_type_int(key_type_name),
			_get_type_class_name(key_type_name),
			_get_type_script(key_type_name),
			_get_type_int(value_type_name),
			_get_type_class_name(value_type_name),
			_get_type_script(value_type_name)
		))
	
	return Dictionary(dict,
		_get_type_int(key_type_name),
		_get_type_class_name(key_type_name),
		_get_type_script(key_type_name),
		_get_type_int(value_type_name),
		_get_type_class_name(value_type_name),
		_get_type_script(value_type_name)
	)


func _get_type_int(type_name: String) -> Variant.Type:
	if type_name in TYPE_NAME_LIST:
		return TYPE_NAME_LIST.find(type_name) as Variant.Type
	
	if ClassDB.class_exists(type_name) or UserClassDB.class_exists(type_name):
		return TYPE_OBJECT
	
	return TYPE_NIL


func _get_type_class_name(type_name: String) -> StringName:
	if ClassDB.class_exists(type_name):
		return type_name
	
	if UserClassDB.class_exists(type_name):
		return UserClassDB.class_get_script(type_name).get_instance_base_type()
	
	return &""


func _get_type_script(type_name: String) -> Script:
	return UserClassDB.class_get_script(type_name) # returns null if it doesn't exist


func _parse_value_list(value_list: String) -> Array:
	value_list = value_list.strip_edges()
	if value_list.begins_with("(") and value_list.ends_with(")"):
		value_list = value_list.trim_prefix("(").trim_suffix(")").strip_edges()
	return Array(Stringifier.split_ignoring_nested(value_list, ",")).map(func(value: String) -> Variant:
		value = value.strip_edges()
		
		if value.begins_with("(") and value.ends_with(")"):
			return _parse_value_list(value)
		
		return _parse_value(value)
	)


## Base class for all not yet available [Resource]s.
@abstract
class PendingResourceBase:
	## Returns whether the underlying [Resource] can be obtained.
	@warning_ignore("unused_parameter")
	func is_ready(resources: Dictionary[int, Object]) -> bool:
		return _is_ready(resources)
	
	## Virtual method. Should return whether the underlying [Resource] can be obtained.
	@abstract func _is_ready(resources: Dictionary[int, Object]) -> bool
	
	## Returns the underlying [Resource], or another [Variant] type that contains
	## the [Resource]. If this pending resource is not ready (see [method is_ready]),
	## returns a fallback value that is as close to the expected value as possible.
	@warning_ignore("unused_parameter")
	func create(resources: Dictionary[int, Object]) -> Variant:
		return _create(resources)
	
	## Virtual method. Should create and return the underlying [Resource], or the
	## [Variant] type that contains the [Resource]. If this pending resource
	## is not ready (see [method _is_ready]), should create a fallback value
	## that is as close to the expected value as possible.
	@abstract func _create(resources: Dictionary[int, Object]) -> Variant
	
	static func _is_ready_safe(value: Variant, resources: Dictionary[int, Object]) -> bool:
		return not value is PendingResourceBase or value.is_ready(resources)


## A [Resource] that is not yet available.
class PendingResource extends PendingResourceBase:
	var id := -1  ## The unique id assigned to the [Resource] when it was saved.
	
	@warning_ignore("shadowed_variable")
	func _init(id: int) -> void:
		self.id = id
	
	func _is_ready(resources: Dictionary[int, Object]) -> bool:
		return id in resources
	
	func _create(resources: Dictionary[int, Object]) -> Object:
		return resources.get(id, null)


## An [Array] of values, where at least one is an unavailable [Resource].
class UntypedPendingResourceArray extends PendingResourceBase:
	var array := []  ## The [Array] of values.
	
	@warning_ignore("shadowed_variable")
	func _init(array: Array) -> void:
		self.array = array
	
	func _is_ready(resources: Dictionary[int, Object]) -> bool:
		return not array.any(func(a: Variant) -> bool: return a is PendingResourceBase and not a.is_ready(resources))
	
	func _create(resources: Dictionary[int, Object]) -> Array:
		return array.map(func(a: Variant) -> Variant:
			if a is PendingResourceBase:
				return a.create(resources)
			return a
		)


## A typed [Array] of potentially unavailable [Resource]s.
class TypedPendingResourceArray extends UntypedPendingResourceArray:
	var array_base: Array  ## The base of the [Array]. It should be typed, and this same [Array] will be returned in [method create].
	
	@warning_ignore("shadowed_variable_base_class", "shadowed_variable")
	func _init(array: Array, array_base: Array) -> void:
		super(array)
		self.array_base = array_base
	
	func _create(resources: Dictionary[int, Object]) -> Array:
		array_base.assign(super(resources))
		return array_base


## An untyped [Dictionary] of potentially unavailable [Resource]s.
class UntypedPendingResourceDictionary extends PendingResourceBase:
	var dict := {} ## The [Dictionary] of values.
	
	@warning_ignore("shadowed_variable")
	func _init(dict: Dictionary) -> void:
		self.dict = dict
	
	func _is_ready(resources: Dictionary[int, Object]) -> bool:
		return dict.keys().all(_is_ready_safe.bind(resources)) and dict.values().all(_is_ready_safe.bind(resources))
	
	func _create(resources: Dictionary[int, Object]) -> Dictionary:
		for key in dict.keys():
			if dict[key] is PendingResourceBase:
				dict[key] = dict[key].create(resources)
			if key is PendingResourceBase:
				dict[key.create(resources)] = dict[key]
				dict.erase(key)
		return dict


## A typed [Dictionary] of potentially unavailable [Resource]s.
class TypedPendingResourceDictionary extends UntypedPendingResourceDictionary:
	var dict_base: Dictionary ## The base of the [Dictionary]. It should be typed, and this same [Dictionary] will be returned in [method create].
	
	@warning_ignore("shadowed_variable_base_class", "shadowed_variable")
	func _init(dict: Dictionary, dict_base: Dictionary) -> void:
		super(dict)
		self.dict_base = dict_base
	
	func _create(resources: Dictionary[int, Object]) -> Dictionary:
		dict_base.assign(super(resources))
		return dict_base


class PendingResourceInstantiator extends PendingResourceBase:
	var instantiator: Callable
	var args: Array
	
	@warning_ignore("shadowed_variable")
	func _init(instantiator: Callable, args: Array) -> void:
		self.instantiator = instantiator
		self.args = args
	
	func _is_ready(resources: Dictionary[int, Object]) -> bool:
		return args.all(_is_ready_safe.bind(resources))
	
	func _create(resources: Dictionary[int, Object]) -> Object:
		for i in args.size():
			if args[i] is PendingResourceBase:
				args[i] = args[i].create(resources)
		return instantiator.callv(args)


class MissingExtResource extends Resource:
	var path := ""
	
	@warning_ignore("shadowed_variable")
	func _init(path: String = "") -> void:
		self.path = path


class Constructor:
	var script_name: String
	var instantiator: Callable
	var add_script_name: bool
	var pack_args: bool
	
	@warning_ignore("shadowed_variable")
	func _init(script_name: String) -> void:
		self.script_name = script_name
		
		var script := UserClassDB.class_get_script(script_name)
		if "_import_packed_static_v" in script and script._import_packed_static_v is Callable:
			instantiator = script._import_packed_static_v
			add_script_name = true
			pack_args = true
		elif "_import_packed_static" in script and script._import_packed_static is Callable:
			instantiator = script._import_packed_static
			add_script_name = true
			pack_args = false
		elif "_import_packed_v" in script and script._import_packed_v is Callable:
			instantiator = script._import_packed_v
			add_script_name = false
			pack_args = true
		elif "_import_packed" in script and script._import_packed is Callable:
			instantiator = script._import_packed
			add_script_name = false
			pack_args = false
		else:
			instantiator = script.new
			add_script_name = false
			pack_args = false
	
	func construct(args: Array = []) -> Object:
		if pack_args:
			if args.any(func(v: Variant) -> bool: return v is PendingResourceBase):
				args = [UntypedPendingResourceArray.new(args)]
			else:
				args = [args]
		if add_script_name:
			args.push_front(script_name)
		
		if args.any(func(v: Variant) -> bool: return v is PendingResourceBase):
			return PendingResourceInstantiator.new(instantiator, args)
		
		var object := instantiator.callv(args) as Object
		assert(object != null, "Could not create object.")
		return object
