## Matcher for verifying that a SpecDouble received a specific method call.
class_name SpecSpyMatcher
extends SpecMatcher

var _method: String
var _expected_count: int = -1
var _expected_args: Array = []
var _check_args: bool = false

func _init(method: String) -> void:
	_method = method

## Require the method to be called exactly N times.
func times(count: int) -> SpecSpyMatcher:
	_expected_count = count
	return self

## Require the method to be called with exactly these arguments.
func with(args: Array) -> SpecSpyMatcher:
	_expected_args = args
	_check_args = true
	return self

func matches(actual: Variant) -> bool:
	if not actual is SpecDouble:
		return false
	
	var d: SpecDouble = actual as SpecDouble
	if not d.has_received(_method):
		return _expected_count == 0  # Only matches if we expected 0 times
		
	var call_count: int = d.get_call_count(_method)
	
	if _expected_count >= 0 and call_count != _expected_count:
		return false
		
	if _check_args:
		var all_args: Array = d.get_call_args(_method)
		var found_args_match: bool = false
		for args: Array in all_args:
			# Array equality is deep in GDScript 4
			if args == _expected_args:
				found_args_match = true
				break
		if not found_args_match:
			return false
			
	return true

func failure_message(actual: Variant) -> String:
	if not actual is SpecDouble:
		return "expected SpecDouble, got %s" % _pp(actual)
	var msg: String = "expected %s to have received '%s'" % [actual._to_string(), _method]
	if _expected_count >= 0:
		msg += " exactly %d times" % _expected_count
	if _check_args:
		msg += " with arguments %s" % _pp(_expected_args)
	return msg

func negated_failure_message(actual: Variant) -> String:
	if not actual is SpecDouble:
		return "expected SpecDouble, got %s" % _pp(actual)
	var msg: String = "expected %s NOT to have received '%s'" % [actual._to_string(), _method]
	if _expected_count >= 0:
		msg += " exactly %d times" % _expected_count
	if _check_args:
		msg += " with arguments %s" % _pp(_expected_args)
	return msg
