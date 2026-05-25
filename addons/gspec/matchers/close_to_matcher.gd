## Float approximate-equality matcher.
## Usage: [code]expect(pi).to(be_close_to(3.14, 0.01))[/code]

class_name SpecCloseToMatcher
extends SpecMatcher

var _expected: float
var _delta: float

func _init(expected: float, delta: float = 0.001) -> void:
	_expected = expected
	_delta = delta

func matches(actual: Variant) -> bool:
	if actual is int:
		return absf(float(actual) - _expected) <= _delta
	if actual is float:
		return absf(actual - _expected) <= _delta
	return false

func failure_message(actual: Variant) -> String:
	return "expected %s to be within %s of %s" % [_pp(actual), _pp(_delta), _pp(_expected)]

func negated_failure_message(actual: Variant) -> String:
	return "expected %s NOT to be within %s of %s" % [_pp(actual), _pp(_delta), _pp(_expected)]
