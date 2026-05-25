## Base class for all GSpec matchers.
##
## Subclasses override [method matches], [method failure_message],
## and [method negated_failure_message] to implement custom assertions.
class_name SpecMatcher
extends RefCounted

## Return [code]true[/code] when [param actual] satisfies this matcher.
func matches(actual: Variant) -> bool:
	return false

## Human-readable explanation shown when [code]expect(x).to(matcher)[/code] fails.
func failure_message(actual: Variant) -> String:
	return "expected condition to be met"

## Human-readable explanation shown when [code]expect(x).not_to(matcher)[/code] fails.
func negated_failure_message(actual: Variant) -> String:
	return "expected condition NOT to be met"

## Pretty-print a value for failure output.
static func _pp(value: Variant) -> String:
	if value == null:
		return "null"
	if value is String:
		return '"%s"' % value
	if value is Array or value is Dictionary:
		return str(value)
	return str(value)
