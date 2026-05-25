## Boolean matchers: be_true, be_false, be_null, be_truthy, be_falsy.

class_name SpecBooleanMatchers
extends RefCounted

#region be_true
class BeTrueMatcher extends SpecMatcher:
	func matches(actual: Variant) -> bool:
		return actual == true

	func failure_message(actual: Variant) -> String:
		return "expected %s to be true" % _pp(actual)

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be true" % _pp(actual)
#endregion

#region be_false
class BeFalseMatcher extends SpecMatcher:
	func matches(actual: Variant) -> bool:
		return actual == false

	func failure_message(actual: Variant) -> String:
		return "expected %s to be false" % _pp(actual)

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be false" % _pp(actual)
#endregion

#region be_null
class BeNullMatcher extends SpecMatcher:
	func matches(actual: Variant) -> bool:
		return actual == null

	func failure_message(actual: Variant) -> String:
		return "expected %s to be null" % _pp(actual)

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be null" % _pp(actual)
#endregion

#region be_truthy
class BeTruthyMatcher extends SpecMatcher:
	func matches(actual: Variant) -> bool:
		if actual == null:
			return false
		if actual is bool:
			return actual
		if actual is int:
			return actual != 0
		if actual is float:
			return actual != 0.0
		if actual is String:
			return not actual.is_empty()
		if actual is Array:
			return not actual.is_empty()
		if actual is Dictionary:
			return not actual.is_empty()
		return true  # Objects and other types are truthy

	func failure_message(actual: Variant) -> String:
		return "expected %s to be truthy" % _pp(actual)

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be truthy" % _pp(actual)
#endregion

#region be_falsy
class BeFalsyMatcher extends SpecMatcher:
	func matches(actual: Variant) -> bool:
		if actual == null:
			return true
		if actual is bool:
			return not actual
		if actual is int:
			return actual == 0
		if actual is float:
			return actual == 0.0
		if actual is String:
			return actual.is_empty()
		if actual is Array:
			return actual.is_empty()
		if actual is Dictionary:
			return actual.is_empty()
		return false

	func failure_message(actual: Variant) -> String:
		return "expected %s to be falsy" % _pp(actual)

	func negated_failure_message(actual: Variant) -> String:
		return "expected %s NOT to be falsy" % _pp(actual)
#endregion
