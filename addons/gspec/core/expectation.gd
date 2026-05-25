## Expectation — the [code]expect(value)[/code] entry point.
##
## Provides [method to] and [method not_to] for chaining with matchers:
## [codeblock]
## expect(5).to(eq(5))       # passes
## expect(5).not_to(eq(3))   # passes
## [/codeblock]
class_name Expectation
extends RefCounted

var _actual: Variant
## Back-reference to the spec that created this expectation,
## so assertion results can be collected.
var _spec: RefCounted  # SpecBase — avoid cyclic class_name

func _init(actual: Variant, spec: RefCounted) -> void:
	_actual = actual
	_spec = spec

## Assert that [param matcher] is satisfied by the actual value.
func to(matcher: SpecMatcher) -> void:
	if not matcher.matches(_actual):
		var msg: String = matcher.failure_message(_actual)
		_spec._record_failure(msg)

## Assert that [param matcher] is NOT satisfied by the actual value.
func not_to(matcher: SpecMatcher) -> void:
	if matcher.matches(_actual):
		var msg: String = matcher.negated_failure_message(_actual)
		_spec._record_failure(msg)
