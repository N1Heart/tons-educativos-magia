## Self-test spec — GSpec testing itself (dogfooding).
## This validates that the core framework works correctly.
extends GSpec

func spec() -> void:
	describe("GSpec Framework", func() -> void:

		#region --- Matchers ---
		describe("Matchers", func() -> void:

			describe("eq()", func() -> void:
				it("passes when values are equal", func() -> void:
					expect(1).to(eq(1))
					expect("hello").to(eq("hello"))
					expect(true).to(eq(true))
					expect(null).to(eq(null))
				)

				it("fails when values differ", func() -> void:
					expect(1).not_to(eq(2))
					expect("hello").not_to(eq("world"))
				)

				it("handles arrays", func() -> void:
					expect([1, 2, 3]).to(eq([1, 2, 3]))
					expect([1, 2]).not_to(eq([1, 2, 3]))
				)

				it("handles dictionaries", func() -> void:
					expect({"a": 1}).to(eq({"a": 1}))
					expect({"a": 1}).not_to(eq({"b": 2}))
				)
			)

			describe("be_true() / be_false()", func() -> void:
				it("matches boolean values", func() -> void:
					expect(true).to(be_true())
					expect(false).to(be_false())
					expect(true).not_to(be_false())
					expect(false).not_to(be_true())
				)
			)

			describe("be_null()", func() -> void:
				it("matches null", func() -> void:
					expect(null).to(be_null())
					expect(1).not_to(be_null())
					expect("").not_to(be_null())
				)
			)

			describe("be_truthy() / be_falsy()", func() -> void:
				it("evaluates truthiness", func() -> void:
					expect(1).to(be_truthy())
					expect("hello").to(be_truthy())
					expect(0).to(be_falsy())
					expect("").to(be_falsy())
					expect(null).to(be_falsy())
				)
			)

			describe("be_greater_than()", func() -> void:
				it("compares numbers", func() -> void:
					expect(5).to(be_greater_than(3))
					expect(3).not_to(be_greater_than(5))
					expect(5).not_to(be_greater_than(5))
				)
			)

			describe("be_less_than()", func() -> void:
				it("compares numbers", func() -> void:
					expect(3).to(be_less_than(5))
					expect(5).not_to(be_less_than(3))
				)
			)

			describe("be_between()", func() -> void:
				it("checks inclusive range", func() -> void:
					expect(5).to(be_between(1, 10))
					expect(1).to(be_between(1, 10))
					expect(10).to(be_between(1, 10))
					expect(0).not_to(be_between(1, 10))
					expect(11).not_to(be_between(1, 10))
				)
			)

			describe("include()", func() -> void:
				it("checks array containment", func() -> void:
					expect([1, 2, 3]).to(include(2))
					expect([1, 2, 3]).not_to(include(5))
				)

				it("checks dictionary key containment", func() -> void:
					expect({"a": 1, "b": 2}).to(include("a"))
					expect({"a": 1}).not_to(include("z"))
				)

				it("checks string containment", func() -> void:
					expect("hello world").to(include("world"))
					expect("hello").not_to(include("xyz"))
				)
			)

			describe("contain_exactly()", func() -> void:
				it("checks exact array elements irrespective of order", func() -> void:
					expect([1, 2, 3]).to(contain_exactly([3, 1, 2]))
					expect([1, 2, 2]).to(contain_exactly([2, 1, 2]))
					expect([1, 2]).not_to(contain_exactly([1, 2, 3]))
					expect([1, 2, 3]).not_to(contain_exactly([1, 2]))
				)
			)

			describe("match_dict()", func() -> void:
				it("checks dictionary subset containment", func() -> void:
					expect({"a": 1, "b": 2, "c": 3}).to(match_dict({"a": 1, "b": 2}))
					expect({"a": 1}).not_to(match_dict({"a": 2}))
					expect({"a": 1}).not_to(match_dict({"b": 1}))
				)
			)

			describe("be_empty()", func() -> void:
				it("checks emptiness", func() -> void:
					expect([]).to(be_empty())
					expect({}).to(be_empty())
					expect("").to(be_empty())
					expect([1]).not_to(be_empty())
					expect({"a": 1}).not_to(be_empty())
					expect("x").not_to(be_empty())
				)
			)

			describe("have_size()", func() -> void:
				it("checks collection size", func() -> void:
					expect([1, 2, 3]).to(have_size(3))
					expect({"a": 1}).to(have_size(1))
					expect("hello").to(have_size(5))
				)
			)

			describe("be_close_to()", func() -> void:
				it("checks float proximity", func() -> void:
					expect(3.14159).to(be_close_to(3.14, 0.01))
					expect(3.14159).not_to(be_close_to(3.0, 0.01))
				)
			)
		)
		#endregion

		#region --- Lifecycle Hooks ---
		describe("Lifecycle Hooks", func() -> void:

			describe("before_each", func() -> void:
				before_each(func() -> void:
					v["counter"] = v.get("counter", 0) + 1
				)

				it("runs before first example", func() -> void:
					expect(v["counter"]).to(be_greater_than(0))
				)

				it("resets v between examples so counter starts fresh", func() -> void:
					# v is cleared between examples, so counter is always 1
					expect(v["counter"]).to(eq(1))
				)
			)

			describe("nested hooks", func() -> void:
				before_each(func() -> void:
					v["outer_ran"] = true
				)

				context("inner context", func() -> void:
					before_each(func() -> void:
						v["inner_ran"] = true
					)

					it("runs both outer and inner hooks", func() -> void:
						expect(v["outer_ran"]).to(be_true())
						expect(v["inner_ran"]).to(be_true())
					)
				)
			)
		)
		#endregion

		#region --- v (shared vars) ---
		describe("v (shared vars dict)", func() -> void:
			before_each(func() -> void:
				v["name"] = "hello"
				v["count"] = 42
			)

			it("is accessible in it blocks", func() -> void:
				expect(v["name"]).to(eq("hello"))
				expect(v["count"]).to(eq(42))
			)

			it("is reset between examples", func() -> void:
				# before_each runs fresh each time, v is cleared
				expect(v["count"]).to(eq(42))
			)

			it("can be mutated within an it block", func() -> void:
				v["count"] = 99
				expect(v["count"]).to(eq(99))
			)

			context("nested context with before_each", func() -> void:
				before_each(func() -> void:
					v["extra"] = "nested"
				)

				it("inherits outer before_each values", func() -> void:
					expect(v["name"]).to(eq("hello"))
					expect(v["extra"]).to(eq("nested"))
				)
			)
		)
		#endregion

		#region --- Async Support ---
		describe("Async Support", func() -> void:
			it("can await signals inside examples", func() -> void:
				var tree: SceneTree = Engine.get_main_loop() as SceneTree
				await tree.create_timer(0.05).timeout
				expect(true).to(be_true())
			)

			context("with async before_each", func() -> void:
				before_each(func() -> void:
					var tree: SceneTree = Engine.get_main_loop() as SceneTree
					await tree.create_timer(0.05).timeout
					v["async_setup"] = true
				)

				it("waits for setup to complete", func() -> void:
					expect(v.get("async_setup")).to(be_true())
				)
			)
		)
		#endregion

		#region --- Test Doubles ---
		describe("Test Doubles (Mock/Spy)", func() -> void:
			before_each(func() -> void:
				v["double"] = double("MyMock").stub("fetch_data", {"id": 1}).stub("do_action")
			)

			it("returns stubbed values", func() -> void:
				var d: SpecDouble = v["double"]
				expect(d.track("fetch_data")).to(eq({"id": 1}))
				expect(d.track("do_action")).to(be_null())
			)

			it("tracks method calls", func() -> void:
				var d: SpecDouble = v["double"]
				d.track("fetch_data", [123, "test"])
				d.track("fetch_data", [456])
				
				expect(d).to(have_received("fetch_data"))
				expect(d).to(have_received("fetch_data").times(2))
				expect(d).not_to(have_received("do_action"))
			)

			it("tracks specific arguments", func() -> void:
				var d: SpecDouble = v["double"]
				d.track("do_action", ["hello", true])
				
				expect(d).to(have_received("do_action").with(["hello", true]))
				expect(d).not_to(have_received("do_action").with(["hello", false]))
			)
		)
		#endregion

		#region --- let_def ---
		describe("let_def()", func() -> void:
			let_def("number", func() -> Variant:
				return 42
			)

			it("provides lazy values via get_let()", func() -> void:
				var val: Variant = get_let("number")
				expect(val).to(eq(42))
			)

			context("with overridden let", func() -> void:
				let_def("number", func() -> Variant:
					return 99
				)

				it("uses the inner definition", func() -> void:
					expect(get_let("number")).to(eq(99))
				)
			)
		)
		#endregion

		#region --- Skipped examples ---
		describe("xit()", func() -> void:
			xit("is marked as pending", func() -> void:
				expect(true).to(be_false())  # Should never run
			)
		)
		#endregion
	)
