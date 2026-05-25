## Living documentation for SpecDouble — GSpec's lightweight mock/spy object.
##
## SpecDouble does NOT auto-intercept real methods (GDScript has no dynamic
## dispatch hook). Instead, production code must call d.track("method", args)
## manually, and tests verify those calls happened via have_received().
extends GSpec

func spec() -> void:

	#region Creation
	describe("SpecDouble.new(name) — creating a double", func() -> void:
		it("can be created with a custom name for readability", func() -> void:
			var d: SpecDouble = double("MyService")
			expect(d).not_to(be_null())
		)

		it("default name is 'Double' when none is provided", func() -> void:
			var d: SpecDouble = double()
			expect(d.name).to(eq("Double"))
		)

		it("_to_string() includes the name for easier debugging", func() -> void:
			var d: SpecDouble = double("Logger")
			expect(str(d)).to(include("Logger"))
		)
	)
	#endregion

	#region stub()
	describe("stub(method, return_val) — configuring return values", func() -> void:
		it("returns the stubbed value when track() is called for that method", func() -> void:
			var d: SpecDouble = double("Calc")
			d.stub("add", 42)
			var result: Variant = d.track("add", [10, 32])
			expect(result).to(eq(42))
		)

		it("returns null for a method that was never stubbed", func() -> void:
			var d: SpecDouble = double("Calc")
			var result: Variant = d.track("unknown_method", [])
			expect(result).to(be_null())
		)

		it("supports method chaining — stub() returns self", func() -> void:
			var d: SpecDouble = double("Service")
			var same: SpecDouble = d.stub("foo", 1).stub("bar", 2)
			expect(same).to(eq(d))
		)

		it("can stub a method to return false (falsy value)", func() -> void:
			var d: SpecDouble = double("Guard")
			d.stub("is_allowed", false)
			expect(d.track("is_allowed", [])).to(be_false())
		)

		it("can stub a method to return a complex object", func() -> void:
			var payload: Dictionary = {"damage": 100, "type": "physical"}
			var d: SpecDouble = double("DamageSource")
			d.stub("get_payload", payload)
			var result: Variant = d.track("get_payload", [])
			expect(result).to(eq(payload))
		)

		it("later stub() call overwrites the earlier one for the same method", func() -> void:
			var d: SpecDouble = double("Toggle")
			d.stub("value", 1)
			d.stub("value", 2)
			expect(d.track("value", [])).to(eq(2))
		)
	)
	#endregion

	#region track() + have_received()
	describe("track() + have_received() — spy behaviour", func() -> void:
		it("have_received passes after calling track() for that method", func() -> void:
			var d: SpecDouble = double("Logger")
			d.track("log", ["hello"])
			expect(d).to(have_received("log"))
		)

		it("have_received fails when the method was never tracked", func() -> void:
			var d: SpecDouble = double("Logger")
			expect(d).not_to(have_received("log"))
		)

		it("have_received passes even when called multiple times", func() -> void:
			var d: SpecDouble = double("Bus")
			d.track("emit", ["event_a"])
			d.track("emit", ["event_b"])
			expect(d).to(have_received("emit"))
		)

		it("tracking one method does not affect detection of another method", func() -> void:
			var d: SpecDouble = double("Service")
			d.track("start", [])
			expect(d).to(have_received("start"))
			expect(d).not_to(have_received("stop"))
		)
	)
	#endregion

	#region get_call_count()
	describe("get_call_count(method) — how many times was it called", func() -> void:
		it("returns 0 for a method that was never tracked", func() -> void:
			var d: SpecDouble = double("Counter")
			expect(d.get_call_count("tick")).to(eq(0))
		)

		it("returns 1 after a single track() call", func() -> void:
			var d: SpecDouble = double("Counter")
			d.track("tick", [])
			expect(d.get_call_count("tick")).to(eq(1))
		)

		it("increments with every additional track() call", func() -> void:
			var d: SpecDouble = double("Counter")
			for _i: int in range(5):
				d.track("tick", [])
			expect(d.get_call_count("tick")).to(eq(5))
		)

		it("counts independently per method name", func() -> void:
			var d: SpecDouble = double("Multi")
			d.track("a", [])
			d.track("a", [])
			d.track("b", [])
			expect(d.get_call_count("a")).to(eq(2))
			expect(d.get_call_count("b")).to(eq(1))
		)
	)
	#endregion

	#region get_call_args()
	describe("get_call_args(method) — inspecting what arguments were passed", func() -> void:
		it("returns an empty array for a method that was never tracked", func() -> void:
			var d: SpecDouble = double("Spy")
			expect(d.get_call_args("send")).to(be_empty())
		)

		it("returns the arguments from a single call as Array[Array]", func() -> void:
			var d: SpecDouble = double("Spy")
			d.track("send", ["hello", 42])
			var calls: Array = d.get_call_args("send")
			expect(calls).to(have_size(1))
			expect(calls[0]).to(eq(["hello", 42]))
		)

		it("records each call's arguments separately", func() -> void:
			var d: SpecDouble = double("Spy")
			d.track("push", [1])
			d.track("push", [2])
			d.track("push", [3])
			var calls: Array = d.get_call_args("push")
			expect(calls).to(have_size(3))
			expect(calls[0]).to(eq([1]))
			expect(calls[1]).to(eq([2]))
			expect(calls[2]).to(eq([3]))
		)

		it("can verify the exact arguments of the most recent call", func() -> void:
			var d: SpecDouble = double("Http")
			d.track("get", ["/health"])
			d.track("get", ["/status"])
			var last_args: Array = d.get_call_args("get").back()
			expect(last_args).to(eq(["/status"]))
		)
	)
	#endregion

	#region doubles as collaborator stubs
	describe("practical pattern — injecting a double as a collaborator", func() -> void:
		it("allows testing a function's behaviour without real dependencies", func() -> void:
			# Simulates injecting a SpecDouble as a fake 'damage calculator'.
			var fake_calc: SpecDouble = double("DamageCalculator")
			fake_calc.stub("compute", 250)

			# System under test calls compute() and uses the result.
			var damage: int = fake_calc.track("compute", [100, 0.5, true]) as int

			expect(damage).to(eq(250))
			expect(fake_calc).to(have_received("compute"))
			expect(fake_calc.get_call_count("compute")).to(eq(1))
			expect(fake_calc.get_call_args("compute")[0]).to(eq([100, 0.5, true]))
		)
	)
	#endregion
