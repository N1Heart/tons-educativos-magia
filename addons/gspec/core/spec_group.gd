## Container for [code]describe[/code] / [code]context[/code] blocks.
##
## Holds child groups, examples, and lifecycle hooks.
## Forms a tree that the runner walks to execute specs.
class_name SpecGroup
extends RefCounted

var description: String
var parent: SpecGroup
var children: Array[RefCounted] = []
var before_each_hooks: Array[Callable] = []
var after_each_hooks: Array[Callable] = []
var before_all_hooks: Array[Callable] = []
var after_all_hooks: Array[Callable] = []
var let_definitions: Dictionary = {}  # { name: Callable }
var is_focused: bool = false

func _init(_description: String, _parent: SpecGroup = null) -> void:
	description = _description
	parent = _parent

## Full describe path from root: "SDamageProcessor > when attacker crits"
func full_description() -> String:
	if parent != null and not parent.description.is_empty():
		return "%s > %s" % [parent.full_description(), description]
	return description

## Nesting depth (0 = root).
func depth() -> int:
	if parent == null:
		return 0
	return parent.depth() + 1

## Collect before_each hooks from root → this group (outermost first).
func collect_before_hooks() -> Array[Callable]:
	var hooks: Array[Callable] = []
	if parent != null:
		hooks.append_array(parent.collect_before_hooks())
	hooks.append_array(before_each_hooks)
	return hooks

## Collect after_each hooks from this group → root (innermost first).
func collect_after_hooks() -> Array[Callable]:
	var hooks: Array[Callable] = []
	hooks.append_array(after_each_hooks)
	if parent != null:
		hooks.append_array(parent.collect_after_hooks())
	return hooks

## Collect let definitions from root → this group (outer overridden by inner).
func collect_let_definitions() -> Dictionary:
	var defs: Dictionary = {}
	if parent != null:
		defs.merge(parent.collect_let_definitions())
	defs.merge(let_definitions, true)  # inner overrides outer
	return defs

## Returns true when this group or any ancestor group is focused.
func is_focused_or_ancestor_focused() -> bool:
	if is_focused:
		return true
	if parent != null:
		return parent.is_focused_or_ancestor_focused()
	return false

## Recursively gather all examples in this group and its children.
func all_examples() -> Array[SpecExample]:
	var result: Array[SpecExample] = []
	for child: Variant in children:
		if child is SpecExample:
			result.append(child)
		elif child is SpecGroup:
			result.append_array(child.all_examples())
	return result

## Break cyclic references to prevent ObjectDB leaks at exit.
func clear() -> void:
	for child: Variant in children:
		if child is SpecGroup or child is SpecExample:
			child.clear()
	children.clear()
	parent = null
	before_each_hooks.clear()
	after_each_hooks.clear()
	before_all_hooks.clear()
	after_all_hooks.clear()
	let_definitions.clear()
