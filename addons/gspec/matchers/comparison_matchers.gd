## Numeric comparison matchers: be_greater_than, be_less_than,
## be_greater_than_or_equal, be_less_than_or_equal, be_between.

class_name SpecComparisonMatchers
extends RefCounted


class BeGreaterThanMatcher extends SpecMatcher:
	var _expected: Variant

	func _init(expected: Variant) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		return actual > _expected

	func failure_message(actual: Variant) -> String:
		return "expected %s to be greater than %s" % [_pp(actual), _pp(_expected)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be greater than %s" % [_pp(actual), _pp(_expected)]


class BeLessThanMatcher extends SpecMatcher:
	var _expected: Variant

	func _init(expected: Variant) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		return actual < _expected

	func failure_message(actual: Variant) -> String:
		return "expected %s to be less than %s" % [_pp(actual), _pp(_expected)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be less than %s" % [_pp(actual), _pp(_expected)]


class BeGreaterThanOrEqualMatcher extends SpecMatcher:
	var _expected: Variant

	func _init(expected: Variant) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		return actual >= _expected

	func failure_message(actual: Variant) -> String:
		return "expected %s to be >= %s" % [_pp(actual), _pp(_expected)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be >= %s" % [_pp(actual), _pp(_expected)]


class BeLessThanOrEqualMatcher extends SpecMatcher:
	var _expected: Variant

	func _init(expected: Variant) -> void:
		_expected = expected

	func matches(actual: Variant) -> bool:
		return actual <= _expected

	func failure_message(actual: Variant) -> String:
		return "expected %s to be <= %s" % [_pp(actual), _pp(_expected)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be <= %s" % [_pp(actual), _pp(_expected)]


class BeBetweenMatcher extends SpecMatcher:
	var _low: Variant
	var _high: Variant

	func _init(low: Variant, high: Variant) -> void:
		_low = low
		_high = high

	func matches(actual: Variant) -> bool:
		return actual >= _low and actual <= _high

	func failure_message(actual: Variant) -> String:
		return "expected %s to be between %s and %s" % [_pp(actual), _pp(_low), _pp(_high)]

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be between %s and %s" % [_pp(actual), _pp(_low), _pp(_high)]
