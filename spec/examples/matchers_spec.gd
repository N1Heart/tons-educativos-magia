## Living documentation for every built-in GSpec matcher.
## Each group covers one matcher family; each it() shows one precise behaviour.
## Includes: eq, boolean, null, truthy/falsy, comparisons, collections,
## type/property, float precision, satisfy, have_attributes, all, change.
extends GSpec

var _counter: int = 0

func spec() -> void:

	#region eq()
	describe("eq() — strict equality", func() -> void:
		it("passes when two integers are identical", func() -> void:
			expect(42).to(eq(42))
		)
		it("passes when two strings are identical", func() -> void:
			expect("hello").to(eq("hello"))
		)
		it("passes when two arrays have the same elements in the same order", func() -> void:
			expect([1, 2, 3]).to(eq([1, 2, 3]))
		)
		it("passes when two dictionaries have the same keys and values", func() -> void:
			expect({"a": 1, "b": 2}).to(eq({"a": 1, "b": 2}))
		)
		it("passes when both sides are null", func() -> void:
			expect(null).to(eq(null))
		)
		it("fails when integer values differ", func() -> void:
			expect(1).not_to(eq(2))
		)
		it("fails when array order differs", func() -> void:
			expect([1, 2, 3]).not_to(eq([3, 2, 1]))
		)
		it("fails when types differ even if values look the same", func() -> void:
			expect(1).not_to(eq("1"))
		)
	)
	#endregion

	#region be_true / be_false
	describe("be_true() / be_false() — strict boolean identity", func() -> void:
		it("be_true passes only for the boolean literal true", func() -> void:
			expect(true).to(be_true())
		)
		it("be_true fails for a truthy non-boolean such as 1", func() -> void:
			expect(1).not_to(be_true())
		)
		it("be_true fails for a non-empty string even though it is truthy", func() -> void:
			expect("yes").not_to(be_true())
		)
		it("be_false passes only for the boolean literal false", func() -> void:
			expect(false).to(be_false())
		)
		it("be_false fails for 0 even though it is falsy", func() -> void:
			expect(0).not_to(be_false())
		)
		it("negation: not_to(be_true()) passes for false", func() -> void:
			expect(false).not_to(be_true())
		)
	)
	#endregion

	#region be_null
	describe("be_null() — null check", func() -> void:
		it("passes when value is null", func() -> void:
			expect(null).to(be_null())
		)
		it("fails for an empty string (not null)", func() -> void:
			expect("").not_to(be_null())
		)
		it("fails for zero (not null)", func() -> void:
			expect(0).not_to(be_null())
		)
		it("fails for false (not null)", func() -> void:
			expect(false).not_to(be_null())
		)
		it("not_to passes when value is a real object", func() -> void:
			expect(RefCounted.new()).not_to(be_null())
		)
	)
	#endregion

	#region be_truthy / be_falsy
	describe("be_truthy() / be_falsy() — GDScript truthiness rules", func() -> void:
		describe("be_truthy — values that evaluate to true", func() -> void:
			it("passes for boolean true", func() -> void:
				expect(true).to(be_truthy())
			)
			it("passes for any non-zero integer", func() -> void:
				expect(99).to(be_truthy())
			)
			it("passes for any non-zero negative integer", func() -> void:
				expect(-1).to(be_truthy())
			)
			it("passes for a non-empty string", func() -> void:
				expect("hello").to(be_truthy())
			)
			it("passes for a non-empty array", func() -> void:
				expect([0]).to(be_truthy())
			)
			it("passes for a non-empty dictionary", func() -> void:
				expect({"k": 0}).to(be_truthy())
			)
			it("passes for any object reference", func() -> void:
				expect(RefCounted.new()).to(be_truthy())
			)
		)

		describe("be_falsy — values that evaluate to false", func() -> void:
			it("passes for null", func() -> void:
				expect(null).to(be_falsy())
			)
			it("passes for boolean false", func() -> void:
				expect(false).to(be_falsy())
			)
			it("passes for integer zero", func() -> void:
				expect(0).to(be_falsy())
			)
			it("passes for float zero", func() -> void:
				expect(0.0).to(be_falsy())
			)
			it("passes for an empty string", func() -> void:
				expect("").to(be_falsy())
			)
			it("passes for an empty array", func() -> void:
				expect([]).to(be_falsy())
			)
			it("passes for an empty dictionary", func() -> void:
				expect({}).to(be_falsy())
			)
		)
	)
	#endregion

	#region Numeric comparisons
	describe("Numeric comparison matchers", func() -> void:
		describe("be_greater_than(n) — actual > n", func() -> void:
			it("passes when actual is strictly greater", func() -> void:
				expect(10).to(be_greater_than(9))
			)
			it("fails when actual equals the threshold", func() -> void:
				expect(5).not_to(be_greater_than(5))
			)
			it("fails when actual is smaller", func() -> void:
				expect(3).not_to(be_greater_than(10))
			)
			it("works with floats", func() -> void:
				expect(1.5).to(be_greater_than(1.4))
			)
		)

		describe("be_less_than(n) — actual < n", func() -> void:
			it("passes when actual is strictly less", func() -> void:
				expect(3).to(be_less_than(4))
			)
			it("fails when actual equals the threshold", func() -> void:
				expect(5).not_to(be_less_than(5))
			)
		)

		describe("be_gte(n) — actual >= n", func() -> void:
			it("passes when actual is greater", func() -> void:
				expect(6).to(be_gte(5))
			)
			it("passes when actual equals the threshold (unlike be_greater_than)", func() -> void:
				expect(5).to(be_gte(5))
			)
			it("fails when actual is smaller", func() -> void:
				expect(4).not_to(be_gte(5))
			)
		)

		describe("be_lte(n) — actual <= n", func() -> void:
			it("passes when actual is less", func() -> void:
				expect(4).to(be_lte(5))
			)
			it("passes when actual equals the threshold", func() -> void:
				expect(5).to(be_lte(5))
			)
			it("fails when actual exceeds the threshold", func() -> void:
				expect(6).not_to(be_lte(5))
			)
		)

		describe("be_between(low, high) — inclusive range", func() -> void:
			it("passes for a value strictly inside the range", func() -> void:
				expect(5).to(be_between(1, 10))
			)
			it("passes for the lower boundary (inclusive)", func() -> void:
				expect(1).to(be_between(1, 10))
			)
			it("passes for the upper boundary (inclusive)", func() -> void:
				expect(10).to(be_between(1, 10))
			)
			it("fails for a value just below the lower boundary", func() -> void:
				expect(0).not_to(be_between(1, 10))
			)
			it("fails for a value just above the upper boundary", func() -> void:
				expect(11).not_to(be_between(1, 10))
			)
		)

		describe("be_close_to(expected, delta) — float approximation", func() -> void:
			it("passes when difference is within the default delta of 0.001", func() -> void:
				expect(1.0005).to(be_close_to(1.0))
			)
			it("passes with a custom delta", func() -> void:
				expect(3.14159).to(be_close_to(3.14, 0.01))
			)
			it("fails when difference exceeds the delta", func() -> void:
				expect(3.14159).not_to(be_close_to(3.0, 0.01))
			)
			it("works with integer actual when compared to float expected", func() -> void:
				expect(1).to(be_close_to(1.0, 0.001))
			)
		)
	)
	#endregion

	#region Collection matchers
	describe("Collection matchers", func() -> void:
		describe("include(value) — containment check", func() -> void:
			context("when actual is an Array", func() -> void:
				it("passes when the element is present", func() -> void:
					expect([1, 2, 3]).to(include(2))
				)
				it("fails when the element is absent", func() -> void:
					expect([1, 2, 3]).not_to(include(99))
				)
			)
			context("when actual is a Dictionary", func() -> void:
				it("passes when the key exists (ignores value)", func() -> void:
					expect({"a": 1, "b": 2}).to(include("a"))
				)
				it("fails when the key is absent", func() -> void:
					expect({"a": 1}).not_to(include("z"))
				)
			)
			context("when actual is a String", func() -> void:
				it("passes when the substring is present", func() -> void:
					expect("hello world").to(include("world"))
				)
				it("fails when the substring is absent", func() -> void:
					expect("hello").not_to(include("xyz"))
				)
			)
		)

		describe("be_empty() — zero-size check", func() -> void:
			it("passes for an empty array", func() -> void:
				expect([]).to(be_empty())
			)
			it("passes for an empty dictionary", func() -> void:
				expect({}).to(be_empty())
			)
			it("passes for an empty string", func() -> void:
				expect("").to(be_empty())
			)
			it("fails for an array with one element", func() -> void:
				expect([0]).not_to(be_empty())
			)
			it("fails for a dictionary with one entry", func() -> void:
				expect({"k": 1}).not_to(be_empty())
			)
			it("fails for a non-empty string", func() -> void:
				expect("x").not_to(be_empty())
			)
		)

		describe("have_size(n) — exact size check", func() -> void:
			it("passes for an array with the expected number of elements", func() -> void:
				expect([1, 2, 3]).to(have_size(3))
			)
			it("passes for a dictionary with the expected number of entries", func() -> void:
				expect({"a": 1, "b": 2}).to(have_size(2))
			)
			it("passes for a string with the expected character count", func() -> void:
				expect("hello").to(have_size(5))
			)
			it("fails when size does not match", func() -> void:
				expect([1, 2]).not_to(have_size(3))
			)
		)

		describe("contain_exactly(array) — same elements regardless of order", func() -> void:
			it("passes when array has exactly the expected elements in any order", func() -> void:
				expect([3, 1, 2]).to(contain_exactly([1, 2, 3]))
			)
			it("passes when order matches exactly", func() -> void:
				expect([1, 2, 3]).to(contain_exactly([1, 2, 3]))
			)
			it("fails when actual has an extra element", func() -> void:
				expect([1, 2, 3, 4]).not_to(contain_exactly([1, 2, 3]))
			)
			it("fails when actual is missing an element", func() -> void:
				expect([1, 2]).not_to(contain_exactly([1, 2, 3]))
			)
			it("fails when elements differ in value", func() -> void:
				expect([1, 2, 99]).not_to(contain_exactly([1, 2, 3]))
			)
		)

		describe("match_dict(subset) — dictionary subset check", func() -> void:
			it("passes when actual dictionary contains all expected key-value pairs", func() -> void:
				expect({"a": 1, "b": 2, "c": 3}).to(match_dict({"a": 1, "b": 2}))
			)
			it("passes when actual matches exactly (no extra keys required)", func() -> void:
				expect({"x": 10}).to(match_dict({"x": 10}))
			)
			it("fails when a required key is missing from actual", func() -> void:
				expect({"a": 1}).not_to(match_dict({"a": 1, "b": 2}))
			)
			it("fails when a key's value differs", func() -> void:
				expect({"a": 99}).not_to(match_dict({"a": 1}))
			)
		)
	)
	#endregion

	#region Type & property matchers
	describe("Type and property matchers", func() -> void:
		describe("be_instance_of(Type) — type check", func() -> void:
			it("passes when the object is an instance of the expected class", func() -> void:
				var failure: SpecFailure = SpecFailure.new("oops")
				expect(failure).to(be_instance_of(SpecFailure))
			)
			it("passes for a subclass (polymorphism)", func() -> void:
				var failure: SpecFailure = SpecFailure.new("oops")
				expect(failure).to(be_instance_of(RefCounted))
			)
			it("fails when the object is a different class", func() -> void:
				var group: SpecGroup = SpecGroup.new("g")
				expect(group).not_to(be_instance_of(SpecFailure))
			)
			it("fails when actual is null", func() -> void:
				expect(null).not_to(be_instance_of(SpecFailure))
			)
		)

		describe("have_property(name) / have_property(name, value)", func() -> void:
			it("passes when the object has the named property", func() -> void:
				var failure: SpecFailure = SpecFailure.new("boom")
				expect(failure).to(have_property("message"))
			)
			it("passes when property exists AND its value matches", func() -> void:
				var failure: SpecFailure = SpecFailure.new("boom")
				expect(failure).to(have_property("message", "boom"))
			)
			it("fails when property value does not match", func() -> void:
				var failure: SpecFailure = SpecFailure.new("boom")
				expect(failure).not_to(have_property("message", "other"))
			)
			it("fails when the property does not exist on the object", func() -> void:
				var failure: SpecFailure = SpecFailure.new("boom")
				expect(failure).not_to(have_property("nonexistent_field"))
			)
		)
	)
	#endregion

	#region satisfy()
	describe("satisfy(predicate, desc?) — custom inline condition", func() -> void:
		it("passes when the predicate returns true for the actual value", func() -> void:
			expect(7).to(satisfy(func(x: Variant) -> bool: return (x as int) % 2 != 0, "be odd"))
		)

		it("fails when the predicate returns false", func() -> void:
			expect(8).not_to(satisfy(func(x: Variant) -> bool: return (x as int) % 2 != 0, "be odd"))
		)

		it("works without a description (generic failure message)", func() -> void:
			expect(42).to(satisfy(func(x: Variant) -> bool: return x == 42))
		)

		it("works on objects — combine multiple property checks in one predicate", func() -> void:
			var failure: SpecFailure = SpecFailure.new("boom")
			expect(failure).to(satisfy(
				func(f: Variant) -> bool: return not (f as SpecFailure).message.is_empty(),
				"have a non-empty message"
			))
		)

		it("passes a multi-condition predicate only when ALL conditions hold", func() -> void:
			expect(50).to(satisfy(
				func(x: Variant) -> bool: return x > 0 and x < 100 and (x as int) % 2 == 0,
				"be a positive even number under 100"
			))
		)
	)
	#endregion

	#region have_attributes()
	describe("have_attributes(dict) — check multiple properties in one call", func() -> void:
		it("passes when all expected key/value pairs match", func() -> void:
			var failure: SpecFailure = SpecFailure.new("oops")
			failure.example_description = "my test"
			expect(failure).to(have_attributes({
				"message": "oops",
				"example_description": "my test",
			}))
		)

		it("fails when any one property value does not match", func() -> void:
			var failure: SpecFailure = SpecFailure.new("oops")
			expect(failure).not_to(have_attributes({"message": "different"}))
		)

		it("fails when a required property does not exist on the object", func() -> void:
			var failure: SpecFailure = SpecFailure.new("oops")
			expect(failure).not_to(have_attributes({"nonexistent_field": true}))
		)

		it("fails for null since null is not an Object", func() -> void:
			expect(null).not_to(have_attributes({"health": 100}))
		)
	)
	#endregion

	#region all()
	describe("all(matcher) — every element in an Array must pass the inner matcher", func() -> void:
		it("passes when every element satisfies the matcher", func() -> void:
			expect([2, 4, 6, 8]).to(all(satisfy(
				func(x: Variant) -> bool: return (x as int) % 2 == 0, "be even"
			)))
		)

		it("passes when every element is greater than a threshold", func() -> void:
			expect([5, 10, 15, 20]).to(all(be_greater_than(4)))
		)

		it("fails when even one element does not satisfy the matcher", func() -> void:
			expect([2, 4, 5, 8]).not_to(all(satisfy(
				func(x: Variant) -> bool: return (x as int) % 2 == 0, "be even"
			)))
		)

		it("passes vacuously for an empty array — no elements to violate the condition", func() -> void:
			expect([]).to(all(be_greater_than(0)))
		)

		it("fails for a non-Array value since all() only applies to arrays", func() -> void:
			expect("not an array").not_to(all(be_true()))
		)

		it("not_to(all) passes when at least one element fails the matcher", func() -> void:
			expect([1, 2, 3, 99]).not_to(all(be_less_than(10)))
		)
	)
	#endregion

	#region change()
	describe("change(observer) — assert that an action mutates an observed value", func() -> void:
		describe(".by(delta) — the value must change by an exact amount", func() -> void:
			it("passes when the value increases by the expected delta", func() -> void:
				_counter = 0
				expect(func() -> void: _counter += 5).to(
					change(func() -> Variant: return _counter).by(5)
				)
			)

			it("passes when the value decreases by the expected delta", func() -> void:
				_counter = 10
				expect(func() -> void: _counter -= 3).to(
					change(func() -> Variant: return _counter).by(-3)
				)
			)

			it("fails when the actual delta differs from the expected delta", func() -> void:
				_counter = 0
				expect(func() -> void: _counter += 1).not_to(
					change(func() -> Variant: return _counter).by(99)
				)
			)
		)

		describe(".to(value) — the value must end at a specific value", func() -> void:
			it("passes when the value ends at the expected value", func() -> void:
				_counter = 3
				expect(func() -> void: _counter = 10).to(
					change(func() -> Variant: return _counter).to(10)
				)
			)

			it("fails when the value ends at a different value", func() -> void:
				_counter = 3
				expect(func() -> void: _counter = 7).not_to(
					change(func() -> Variant: return _counter).to(10)
				)
			)
		)

		describe(".from(old).to(new) — assert the full before → after transition", func() -> void:
			it("passes when value starts at 'from' and ends at 'to'", func() -> void:
				_counter = 0
				expect(func() -> void: _counter = 1).to(
					change(func() -> Variant: return _counter).from(0).to(1)
				)
			)

			it("fails when the starting value does not match 'from'", func() -> void:
				_counter = 5
				expect(func() -> void: _counter = 1).not_to(
					change(func() -> Variant: return _counter).from(0).to(1)
				)
			)
		)

		describe("bare change(observer) — value must change in any way", func() -> void:
			it("passes when the value changes at all", func() -> void:
				_counter = 42
				expect(func() -> void: _counter += 1).to(
					change(func() -> Variant: return _counter)
				)
			)

			it("fails when the action leaves the value unchanged", func() -> void:
				_counter = 42
				expect(func() -> void: pass).not_to(
					change(func() -> Variant: return _counter)
				)
			)
		)
	)
	#endregion
