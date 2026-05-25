## A lightweight mock/spy object for GSpec.
## Since GDScript doesn't allow dynamic method overriding,
## this class acts as a dummy object where you manually call `track(method, args)`.
##
## Example:
## [codeblock]
## var d = double("MyClass")
## d.stub("do_something", 42)
##
## # Inject `d` into your system, and inside your system:
## # d.track("do_something", ["arg1"])
##
## expect(d).to(have_received("do_something"))
## [/codeblock]
class_name SpecDouble
extends RefCounted

var name: String
var _stubs: Dictionary = {}
var _calls: Dictionary = {}

func _init(_name: String = "Double") -> void:
	name = _name

## Define a return value for a tracked method. Returns self for chaining.
func stub(method: String, return_val: Variant = null) -> SpecDouble:
	_stubs[method] = return_val
	return self

## Record a method call with its arguments, and return the stubbed value.
## Your production code (or tests) should call this in place of real methods.
func track(method: String, args: Array = []) -> Variant:
	if not _calls.has(method):
		_calls[method] = []
	_calls[method].append(args)
	return _stubs.get(method, null)

## Check if the method was tracked at least once.
func has_received(method: String) -> bool:
	return _calls.has(method) and _calls[method].size() > 0

## Get the total number of times the method was tracked.
func get_call_count(method: String) -> int:
	if not _calls.has(method):
		return 0
	return _calls[method].size()

## Get the array of arguments for all calls to the method.
## Returns Array[Array] where each inner array is one call's arguments.
func get_call_args(method: String) -> Array:
	if not _calls.has(method):
		return []
	return _calls[method]

func _to_string() -> String:
	return "<SpecDouble: %s>" % name
