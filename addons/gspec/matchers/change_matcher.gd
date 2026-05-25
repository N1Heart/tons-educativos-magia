## Change matcher — asserts that calling an action changes an observed value.
##
## Usage:
## [codeblock]
## expect(action).to(change(func(): return counter))
## expect(action).to(change(func(): return counter).by(1))
## expect(action).to(change(func(): return counter).to(5))
## expect(action).to(change(func(): return counter).from(0).to(1))
## [/codeblock]
class_name SpecChangeMatcher
extends SpecMatcher

enum _Mode { ANY, BY, TO, FROM_TO }

var _observer: Callable
var _mode: _Mode = _Mode.ANY
var _expected_by: Variant = null
var _expected_to: Variant = null
var _expected_from: Variant = null

## Captured during matches() so failure_message() doesn't re-run the action.
var _before: Variant = null
var _after: Variant = null

func _init(observer: Callable) -> void:
	_observer = observer

## Assert the value changes by exactly [param amount].
func by(amount: Variant) -> SpecChangeMatcher:
	_mode = _Mode.BY
	_expected_by = amount
	return self

## Assert the value changes to [param new_val]. Can be chained after [method from].
func to(new_val: Variant) -> SpecChangeMatcher:
	if _mode == _Mode.ANY or _mode == _Mode.TO:
		_mode = _Mode.TO
	# from(...).to(...) sets FROM_TO mode
	if _expected_from != null:
		_mode = _Mode.FROM_TO
	_expected_to = new_val
	return self

## Assert the value starts from [param old_val]. Chain with [method to].
func from(old_val: Variant) -> SpecChangeMatcher:
	_expected_from = old_val
	if _expected_to != null:
		_mode = _Mode.FROM_TO
	return self

func matches(actual: Variant) -> bool:
	_before = _observer.call()
	if actual is Callable:
		actual.call()
	_after = _observer.call()

	match _mode:
		_Mode.ANY:
			return _before != _after
		_Mode.BY:
			return (_after - _before) == _expected_by
		_Mode.TO:
			return _after == _expected_to
		_Mode.FROM_TO:
			return _before == _expected_from and _after == _expected_to
	return false

func failure_message(_action: Variant) -> String:
	match _mode:
		_Mode.ANY:
			return "expected value to change, but it stayed at %s" % _pp(_before)
		_Mode.BY:
			return "expected value to change by %s, but changed from %s to %s (delta: %s)" % [
				_pp(_expected_by), _pp(_before), _pp(_after), _pp(_after - _before)
			]
		_Mode.TO:
			return "expected value to change to %s, but was %s after action" % [
				_pp(_expected_to), _pp(_after)
			]
		_Mode.FROM_TO:
			return "expected value to change from %s to %s, but was %s → %s" % [
				_pp(_expected_from), _pp(_expected_to), _pp(_before), _pp(_after)
			]
	return "expected value to change"

func negated_failure_message(_actual: Variant) -> String:
	match _mode:
		_Mode.ANY:
			return "expected the value NOT to change"
		_Mode.BY:
			return "expected the value NOT to change by %s" % _pp(_expected_by)
		_Mode.TO:
			return "expected the value NOT to change to %s" % _pp(_expected_to)
		_Mode.FROM_TO:
			return "expected the value NOT to change from %s to %s" % [_pp(_expected_from), _pp(_expected_to)]
	return "expected value NOT to change"
