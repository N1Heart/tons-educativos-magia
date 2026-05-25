## Represents a single test example — one [code]it("...", func(): ...)[/code] block.
class_name SpecExample
extends RefCounted

enum Status { PENDING, PASSED, FAILED, ERROR }

var description: String
var block: Callable
var group: RefCounted  # SpecGroup parent
var status: Status = Status.PENDING
var failures: Array[SpecFailure] = []
var error_message: String = ""
var duration_ms: float = 0.0
## When true, the example is skipped (marked pending).
var is_skipped: bool = false
## When true, only focused examples (and those in focused groups) run.
var is_focused: bool = false

func _init(_description: String, _block: Callable, _group: RefCounted) -> void:
	description = _description
	block = _block
	group = _group

## Construct the full human-readable path: "ParentGroup > ChildContext > description"
func full_description() -> String:
	var path: String = group.full_description() if group != null else ""
	if path.is_empty():
		return description
	return "%s %s" % [path, description]

## Collect all before_each hooks from root → leaf order.
func collect_before_hooks() -> Array[Callable]:
	var hooks: Array[Callable] = []
	if group != null:
		hooks.append_array(group.collect_before_hooks())
	return hooks

## Collect all after_each hooks from leaf → root order.
func collect_after_hooks() -> Array[Callable]:
	var hooks: Array[Callable] = []
	if group != null:
		hooks.append_array(group.collect_after_hooks())
	return hooks

## Break cyclic references to prevent ObjectDB leaks at exit.
func clear() -> void:
	block = Callable()
	group = null
	failures.clear()
