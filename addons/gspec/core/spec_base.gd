## GSpec — RSpec-style BDD testing framework for Godot 4.
##
## Extend this class and override [method spec] to define your tests:
## [codeblock]
## extends GSpec
##
## func spec() -> void:
##     describe("MyClass", func() -> void:
##         before_each(func() -> void:
##             # setup
##         )
##         it("does something", func() -> void:
##             expect(1 + 1).to(eq(2))
##         )
##     )
## [/codeblock]
class_name GSpec
extends RefCounted

#region --- Internal State ---
var _root_group: SpecGroup
var _current_group: SpecGroup
var _current_context: SpecContext
var _current_example: SpecExample
var _current_failures: Array[SpecFailure] = []
## Shared mutable context for the current example.
## Use this instead of local variables when you need before_each to
## set values that it blocks read — GDScript lambdas capture by value,
## so reassigning a captured local doesn't propagate across closures.
##
## [codeblock]
## before_each(func() -> void:
##     v["entity"] = EntityResource.new()   # ✅ works
## )
## it("reads it", func() -> void:
##     var e: EntityResource = v["entity"]
##     expect(e).not_to(be_null())
## )
## [/codeblock]
var v: Dictionary = {}
## Registry for shared example groups declared with [method shared_examples].
var _shared_examples: Dictionary = {}
#endregion

func _init() -> void:
	_root_group = SpecGroup.new("")
	_current_group = _root_group

#region --- DSL: Structure ---

## Override this method in your spec file to define tests.
func spec() -> void:
	pass

## Define a describe block — groups related examples.
## [codeblock]
## describe("Calculator", func() -> void:
##     it("adds numbers", func() -> void:
##         expect(1 + 1).to(eq(2))
##     )
## )
## [/codeblock]
func describe(description: String, block: Callable) -> void:
	var group: SpecGroup = SpecGroup.new(description, _current_group)
	_current_group.children.append(group)

	var previous_group: SpecGroup = _current_group
	_current_group = group
	block.call()
	_current_group = previous_group

## Alias for [method describe]. Use for conditional sub-grouping.
## [codeblock]
## context("when input is negative", func() -> void: ...)
## [/codeblock]
func context(description: String, block: Callable) -> void:
	describe(description, block)

## Define a single test example.
func it(description: String, block: Callable) -> void:
	var example: SpecExample = SpecExample.new(description, block, _current_group)
	_current_group.children.append(example)

## Define a skipped/pending example (no block needed).
func xit(description: String, _block: Callable = func() -> void: pass) -> void:
	var example: SpecExample = SpecExample.new(description, _block, _current_group)
	example.is_skipped = true
	_current_group.children.append(example)

## Define a focused example. When any [code]fit[/code] or [code]fdescribe[/code]
## exists in the file, only focused items run.
func fit(description: String, block: Callable) -> void:
	var example: SpecExample = SpecExample.new(description, block, _current_group)
	example.is_focused = true
	_current_group.children.append(example)

## Define a focused describe block. All examples inside will run in focus mode.
func fdescribe(description: String, block: Callable) -> void:
	var group: SpecGroup = SpecGroup.new(description, _current_group)
	group.is_focused = true
	_current_group.children.append(group)

	var previous_group: SpecGroup = _current_group
	_current_group = group
	block.call()
	_current_group = previous_group

## Alias for [method fdescribe].
func fcontext(description: String, block: Callable) -> void:
	fdescribe(description, block)

## Declare a shared example group, callable later via [method it_behaves_like].
## [codeblock]
## shared_examples("validates input", func(min_val: int) -> void:
##     it("rejects values below min", func() -> void:
##         expect(min_val - 1).to(be_less_than(min_val))
##     )
## )
## [/codeblock]
func shared_examples(name: String, block: Callable) -> void:
	_shared_examples[name] = block

## Include a shared example group in the current context.
func it_behaves_like(name: String, params: Array = []) -> void:
	if not _shared_examples.has(name):
		push_error("GSpec: shared_examples '%s' not found" % name)
		return
	var block: Callable = _shared_examples[name] as Callable
	block.callv(params)

#endregion

#region --- DSL: Lifecycle Hooks ---

## Register a setup hook for the current group. Runs before each example.
## Parent hooks run before child hooks (outermost first).
func before_each(block: Callable) -> void:
	_current_group.before_each_hooks.append(block)

## Register a teardown hook for the current group. Runs after each example.
## Child hooks run before parent hooks (innermost first).
func after_each(block: Callable) -> void:
	_current_group.after_each_hooks.append(block)

## Register a setup hook that runs once before all examples in the current group.
func before_all(block: Callable) -> void:
	_current_group.before_all_hooks.append(block)

## Register a teardown hook that runs once after all examples in the current group.
func after_all(block: Callable) -> void:
	_current_group.after_all_hooks.append(block)

## Define a lazy, memoized variable accessible via [method get_let].
## Re-evaluated for each example.
## [codeblock]
## let_def("entity", func() -> Variant:
##     return EntityResource.new()
## )
## # ...
## var e: EntityResource = get_let("entity") as EntityResource
## [/codeblock]
func let_def(name: String, block: Callable) -> void:
	_current_group.let_definitions[name] = block

## Retrieve a let-defined variable (lazy + memoized per example).
func get_let(name: String) -> Variant:
	if _current_context == null:
		push_error("GSpec: get_let() called outside of an example")
		return null
	return _current_context.get_let(name)

#endregion

#region --- DSL: Expectations ---

## Create an expectation on [param actual].
## Chain with [method Expectation.to] or [method Expectation.not_to].
func expect(actual: Variant) -> Expectation:
	return Expectation.new(actual, self)

#endregion

#region --- DSL: Matcher Factories ---
## These are convenience functions that create matcher instances.
## Call them inside [code]expect(...).to(...)[/code].

func eq(expected: Variant) -> SpecMatcher:
	return SpecEqMatcher.new(expected)

func be_true() -> SpecMatcher:
	return SpecBooleanMatchers.BeTrueMatcher.new()

func be_false() -> SpecMatcher:
	return SpecBooleanMatchers.BeFalseMatcher.new()

func be_null() -> SpecMatcher:
	return SpecBooleanMatchers.BeNullMatcher.new()

func be_truthy() -> SpecMatcher:
	return SpecBooleanMatchers.BeTruthyMatcher.new()

func be_falsy() -> SpecMatcher:
	return SpecBooleanMatchers.BeFalsyMatcher.new()

func be_greater_than(expected: Variant) -> SpecMatcher:
	return SpecComparisonMatchers.BeGreaterThanMatcher.new(expected)

func be_less_than(expected: Variant) -> SpecMatcher:
	return SpecComparisonMatchers.BeLessThanMatcher.new(expected)

func be_gte(expected: Variant) -> SpecMatcher:
	return SpecComparisonMatchers.BeGreaterThanOrEqualMatcher.new(expected)

func be_lte(expected: Variant) -> SpecMatcher:
	return SpecComparisonMatchers.BeLessThanOrEqualMatcher.new(expected)

func be_between(low: Variant, high: Variant) -> SpecMatcher:
	return SpecComparisonMatchers.BeBetweenMatcher.new(low, high)

func include(expected: Variant) -> SpecMatcher:
	return SpecCollectionMatchers.IncludeMatcher.new(expected)

func contain_exactly(expected: Array) -> SpecMatcher:
	return SpecCollectionMatchers.ContainExactlyMatcher.new(expected)

func match_dict(expected: Dictionary) -> SpecMatcher:
	return SpecCollectionMatchers.IncludeDictMatcher.new(expected)

func be_empty() -> SpecMatcher:
	return SpecCollectionMatchers.BeEmptyMatcher.new()

func have_size(expected_size: int) -> SpecMatcher:
	return SpecCollectionMatchers.HaveSizeMatcher.new(expected_size)

func be_instance_of(expected_type: Variant) -> SpecMatcher:
	return SpecTypeMatcher.new(expected_type)

func have_property(name: String, value: Variant = "__NO_CHECK__") -> SpecMatcher:
	if value == "__NO_CHECK__":
		return SpecPropertyMatcher.new(name)
	return SpecPropertyMatcher.new(name, value, true)

func be_close_to(expected: float, delta: float = 0.001) -> SpecMatcher:
	return SpecCloseToMatcher.new(expected, delta)

## Pass when the [param predicate] Callable returns true for the actual value.
## [codeblock]
## expect(5).to(satisfy(func(x: int) -> bool: return x > 0, "be positive"))
## [/codeblock]
func satisfy(predicate: Callable, description: String = "") -> SpecMatcher:
	return SpecSatisfyMatcher.new(predicate, description)

## Pass when the actual object has all the expected property/value pairs.
## [codeblock]
## expect(entity).to(have_attributes({"health": 100, "name": "Hero"}))
## [/codeblock]
func have_attributes(expected: Dictionary) -> SpecMatcher:
	return SpecAttributesMatcher.new(expected)

## Pass when every element in an Array satisfies the inner matcher.
## [codeblock]
## expect([2, 4, 6]).to(all(satisfy(func(x): return x % 2 == 0)))
## [/codeblock]
func all(matcher: SpecMatcher) -> SpecMatcher:
	return SpecAllMatcher.new(matcher)

## Assert that calling [param action] changes the value returned by [param observer].
## Chain [code].by(n)[/code], [code].to(val)[/code], or [code].from(old).to(new)[/code].
## [codeblock]
## expect(func(): counter += 1).to(change(func(): return counter).by(1))
## [/codeblock]
func change(observer: Callable) -> SpecChangeMatcher:
	return SpecChangeMatcher.new(observer)

#endregion

#region --- Test Doubles (Mocks/Spies) ---

## Create a new SpecDouble (mock/spy object).
func double(name: String = "Double") -> SpecDouble:
	return SpecDouble.new(name)

## Matcher to check if a SpecDouble received a specific method call.
## Usage: expect(my_double).to(have_received("method_name"))
func have_received(method: String) -> SpecSpyMatcher:
	return SpecSpyMatcher.new(method)

#endregion

#region --- Internal ---

## Called by Expectation when an assertion fails.
func _record_failure(message: String) -> void:
	var failure: SpecFailure = SpecFailure.new(message)
	if _current_example != null:
		failure.example_description = _current_example.description
		failure.group_path = _current_example.group.full_description() if _current_example.group != null else ""
	_current_failures.append(failure)

## Execute a single example with full lifecycle.
func _run_example(example: SpecExample) -> void:
	if example.is_skipped:
		example.status = SpecExample.Status.PENDING
		return

	_current_example = example
	_current_failures = []
	v.clear() # Reset shared vars for each example

	# Build context with all let definitions collected from the group hierarchy
	var let_defs: Dictionary = example.group.collect_let_definitions() if example.group != null else {}
	_current_context = SpecContext.new(let_defs)

	var start_time: int = Time.get_ticks_msec()

	# Run before_each hooks (outermost → innermost)
	var before_hooks: Array[Callable] = example.collect_before_hooks()
	for hook: Callable in before_hooks:
		await hook.call()

	await example.block.call()

	# Run after_each hooks (innermost → outermost)
	var after_hooks: Array[Callable] = example.collect_after_hooks()
	for hook: Callable in after_hooks:
		await hook.call()

	var end_time: int = Time.get_ticks_msec()
	example.duration_ms = float(end_time - start_time)

	if _current_failures.is_empty():
		example.status = SpecExample.Status.PASSED
	else:
		example.status = SpecExample.Status.FAILED
		example.failures = _current_failures.duplicate()

	_current_example = null
	_current_context = null
	_current_failures = []

## Build the spec tree by calling spec().
func _build_tree() -> void:
	spec()

## Access the root group (used by runner/formatter).
func _get_root_group() -> SpecGroup:
	return _root_group

## Clean up cyclic references to prevent ObjectDB leaks.
func clear() -> void:
	if _root_group != null:
		_root_group.clear()
	_root_group = null
	_current_group = null
	_current_context = null
	_current_example = null
	_current_failures.clear()
	v.clear()
	_shared_examples.clear()

#endregion
