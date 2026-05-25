## Runtime context for a single example execution.
##
## Holds lazily-evaluated [code]let[/code] values and provides
## a clean sandbox per test run.
class_name SpecContext
extends RefCounted

var _let_definitions: Dictionary = {}  # { name: Callable }
var _let_cache: Dictionary = {}        # { name: Variant }  — memoized

func _init(let_definitions: Dictionary) -> void:
	_let_definitions = let_definitions

## Retrieve a let-defined value (lazy + memoized per example).
func get_let(name: String) -> Variant:
	if _let_cache.has(name):
		return _let_cache[name]

	if not _let_definitions.has(name):
		push_error("GSpec: let(\"%s\") is not defined in this context" % name)
		return null

	var value: Variant = _let_definitions[name].call()
	_let_cache[name] = value
	return value

## Check if a let variable is defined.
func has_let(name: String) -> bool:
	return _let_definitions.has(name)

## Reset memoized values (called between examples).
func reset() -> void:
	_let_cache.clear()
