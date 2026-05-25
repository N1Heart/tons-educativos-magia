## Strict equality matcher.
## Usage: [code]expect(x).to(eq(5))[/code]
class_name SpecEqMatcher
extends SpecMatcher

var _expected: Variant

func _init(expected: Variant) -> void:
	_expected = expected

func matches(actual: Variant) -> bool:
	return actual == _expected

func failure_message(actual: Variant) -> String:
	return "expected %s to equal %s" % [_pp(actual), _pp(_expected)]

func negated_failure_message(actual: Variant) -> String:
	return "expected %s NOT to equal %s" % [_pp(actual), _pp(_expected)]
