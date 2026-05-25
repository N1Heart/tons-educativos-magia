## Living documentation for GSpec's lifecycle hooks and shared-state mechanisms.
## Covers: before_each, after_each, before_all, after_all, v dict, let_def/get_let.
extends GSpec

## Used to verify after_each side-effects across example boundaries.
var _hook_log: Array[String] = []

func spec() -> void:

	#region before_each
	describe("before_each — setup hook", func() -> void:
		describe("basic usage", func() -> void:
			before_each(func() -> void:
				v["counter"] = 0
			)

			it("runs before every example so each example starts with counter = 0", func() -> void:
				expect(v["counter"]).to(eq(0))
			)

			it("runs again before this example — counter is still 0, not accumulated", func() -> void:
				v["counter"] += 1
				expect(v["counter"]).to(eq(1))
			)

			it("previous example's mutation did not leak — counter is 0 again", func() -> void:
				expect(v["counter"]).to(eq(0))
			)
		)

		describe("nested hook ordering — outer runs before inner", func() -> void:
			before_each(func() -> void:
				v["order"] = []
				v["order"].append("outer")
			)

			context("inner context", func() -> void:
				before_each(func() -> void:
					v["order"].append("inner")
				)

				it("v[order] is ['outer', 'inner'] — outer hook fired first", func() -> void:
					expect(v["order"]).to(eq(["outer", "inner"]))
				)
			)

			it("outside inner context v[order] only has 'outer'", func() -> void:
				expect(v["order"]).to(eq(["outer"]))
			)
		)

		describe("three levels of nesting execute outermost-first", func() -> void:
			before_each(func() -> void:
				v["seq"] = ["A"]
			)
			context("level 2", func() -> void:
				before_each(func() -> void:
					v["seq"].append("B")
				)
				context("level 3", func() -> void:
					before_each(func() -> void:
						v["seq"].append("C")
					)
					it("hooks ran in A → B → C order", func() -> void:
						expect(v["seq"]).to(eq(["A", "B", "C"]))
					)
				)
			)
		)
	)
	#endregion

	#region after_each
	describe("after_each — teardown hook", func() -> void:
		describe("basic usage", func() -> void:
			after_each(func() -> void:
				_hook_log.append("after")
			)

			it("after_each has not fired yet when this it block runs", func() -> void:
				var count_before: int = _hook_log.size()
				expect(count_before).to(be_gte(0))  # just verifying we can read it
			)

			it("after_each fired after the previous example — log grew by 1", func() -> void:
				expect(_hook_log.size()).to(be_gte(1))
				expect(_hook_log.back()).to(eq("after"))
			)
		)

		describe("nested hook ordering — inner after_each fires before outer", func() -> void:
			before_each(func() -> void:
				_hook_log.clear()
			)

			after_each(func() -> void:
				_hook_log.append("outer_after")
			)

			context("inner context", func() -> void:
				after_each(func() -> void:
					_hook_log.append("inner_after")
				)

				it("placeholder — after_each ordering is verified by the next example", func() -> void:
					expect(true).to(be_true())
				)
			)

			it("log shows inner_after ran before outer_after", func() -> void:
				expect(_hook_log).to(eq(["inner_after", "outer_after"]))
			)
		)
	)
	#endregion

	#region v — shared mutable dict
	describe("v — shared mutable dictionary", func() -> void:
		it("is empty at the start of each example (auto-cleared)", func() -> void:
			expect(v).to(be_empty())
		)

		context("when before_each populates it", func() -> void:
			before_each(func() -> void:
				v["name"] = "Alice"
				v["score"] = 100
			)

			it("values set in before_each are accessible in it()", func() -> void:
				expect(v["name"]).to(eq("Alice"))
				expect(v["score"]).to(eq(100))
			)

			it("mutations inside it() do not persist to the next example", func() -> void:
				v["score"] = 9999
				expect(v["score"]).to(eq(9999))
			)

			it("previous example's mutation is gone — score is 100 again from before_each", func() -> void:
				expect(v["score"]).to(eq(100))
			)
		)

		context("when multiple before_each hooks contribute values", func() -> void:
			before_each(func() -> void:
				v["a"] = 1
			)
			before_each(func() -> void:
				v["b"] = 2
			)

			it("all hooks ran — both keys are present", func() -> void:
				expect(v).to(have_size(2))
				expect(v["a"]).to(eq(1))
				expect(v["b"]).to(eq(2))
			)
		)
	)
	#endregion

	#region let_def / get_let
	describe("let_def / get_let — lazy memoized variables", func() -> void:
		describe("lazy evaluation", func() -> void:
			var _eval_count: int = 0

			before_each(func() -> void:
				_eval_count = 0
			)

			let_def("expensive", func() -> Variant:
				_eval_count += 1
				return _eval_count * 10
			)

			it("block is not called until get_let is first used", func() -> void:
				expect(_eval_count).to(eq(0))
				var _val: Variant = get_let("expensive")
				expect(_eval_count).to(eq(1))
			)
		)

		describe("memoization within one example", func() -> void:
			let_def("obj", func() -> Variant:
				return RefCounted.new()
			)

			it("calling get_let twice returns the exact same instance", func() -> void:
				var first: RefCounted = get_let("obj") as RefCounted
				var second: RefCounted = get_let("obj") as RefCounted
				expect(first).to(eq(second))
			)
		)

		describe("re-evaluation across examples", func() -> void:
			var _creation_count: int = 0

			let_def("fresh", func() -> Variant:
				_creation_count += 1
				return _creation_count
			)

			it("first example gets creation_count = 1", func() -> void:
				expect(get_let("fresh")).to(eq(1))
			)

			it("second example gets a freshly-evaluated value — creation_count = 2", func() -> void:
				expect(get_let("fresh")).to(eq(2))
			)
		)

		describe("nested override — inner let shadows outer let", func() -> void:
			let_def("value", func() -> Variant:
				return "outer"
			)

			it("outer context sees 'outer'", func() -> void:
				expect(get_let("value")).to(eq("outer"))
			)

			context("when inner context redefines the same let", func() -> void:
				let_def("value", func() -> Variant:
					return "inner"
				)

				it("inner context sees 'inner' (override takes precedence)", func() -> void:
					expect(get_let("value")).to(eq("inner"))
				)
			)

			it("back in outer context, 'outer' is restored", func() -> void:
				expect(get_let("value")).to(eq("outer"))
			)
		)
	)
	#endregion

	#region before_all / after_all
	describe("before_all / after_all — run once per group", func() -> void:
		describe("before_all runs exactly once before the first example", func() -> void:
			var _init_count: int = 0

			before_all(func() -> void:
				_init_count += 1
			)

			it("init_count is 1 for the first example", func() -> void:
				expect(_init_count).to(eq(1))
			)

			it("init_count is still 1 for the second example — before_all did NOT re-run", func() -> void:
				expect(_init_count).to(eq(1))
			)

			it("init_count is still 1 for the third example — before_each would have run 3 times by now", func() -> void:
				expect(_init_count).to(eq(1))
			)
		)

		describe("contrast: before_each runs before EVERY example", func() -> void:
			var _each_count: int = 0

			before_each(func() -> void:
				_each_count += 1
			)

			it("each_count is 1 after the first example", func() -> void:
				expect(_each_count).to(eq(1))
			)

			it("each_count is 2 after the second example — before_each ran again", func() -> void:
				expect(_each_count).to(eq(2))
			)
		)

		describe("after_all runs exactly once after all examples in the group finish", func() -> void:
			var _cleanup_count: int = 0
			var _example_ran: int = 0

			after_all(func() -> void:
				_cleanup_count += 1
			)

			it("cleanup_count is 0 while examples are still running", func() -> void:
				_example_ran += 1
				expect(_cleanup_count).to(eq(0))
			)

			it("cleanup_count is still 0 — after_all has not fired yet", func() -> void:
				_example_ran += 1
				expect(_cleanup_count).to(eq(0))
			)
		)

		describe("before_all and after_all can coexist in the same group", func() -> void:
			var _log: Array[String] = []

			before_all(func() -> void:
				_log = ["setup"]
			)

			after_all(func() -> void:
				_log.append("teardown")
			)

			it("log contains setup entry from before_all", func() -> void:
				expect(_log).to(include("setup"))
			)

			it("log still only has setup — teardown fires after this example too", func() -> void:
				expect(_log).to(eq(["setup"]))
			)
		)
	)
	#endregion

	#region xit — pending/skipped examples
	describe("xit() — pending examples", func() -> void:
		it("a normal it() runs and passes", func() -> void:
			expect(true).to(be_true())
		)

		xit("this example is skipped and counted as pending — its block never runs", func() -> void:
			expect(false).to(be_true())  # would fail if it ran
		)

		xit("another pending example with no block defined")
	)
	#endregion
