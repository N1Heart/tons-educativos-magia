## Living documentation for advanced GSpec features:
## shared_examples / it_behaves_like, and fit / fdescribe / fcontext.
extends GSpec

func spec() -> void:

	#region shared_examples / it_behaves_like
	describe("shared_examples / it_behaves_like — reusable test groups", func() -> void:

		# Define a shared group parametrised by the expected message string.
		# The block registers a before_each internally so the object is created
		# at run-time (not at describe-time when v is still empty).
		shared_examples("an object with a message", func(expected_msg: String) -> void:
			before_each(func() -> void:
				v["obj"] = SpecFailure.new(expected_msg)
			)
			it("has a non-empty message property", func() -> void:
				expect(v["obj"]).to(have_property("message"))
				expect(v["obj"]).not_to(have_property("message", ""))
			)
			it("message equals the expected value", func() -> void:
				expect(v["obj"]).to(have_property("message", expected_msg))
			)
		)

		# Include the shared group for two different message strings.
		describe("SpecFailure with 'something went wrong'", func() -> void:
			it_behaves_like("an object with a message", ["something went wrong"])
		)

		describe("reusing the same shared group with a different message", func() -> void:
			it_behaves_like("an object with a message", ["another error"])
		)

		describe("shared_examples without parameters — shared setup only", func() -> void:
			shared_examples("basic integer math", func() -> void:
				it("addition is commutative", func() -> void:
					expect(3 + 5).to(eq(5 + 3))
				)
				it("multiplication distributes over addition", func() -> void:
					expect(2 * (3 + 4)).to(eq(2 * 3 + 2 * 4))
				)
			)

			context("included once", func() -> void:
				it_behaves_like("basic integer math")
			)

			context("included again in a different context — same tests, same results", func() -> void:
				it_behaves_like("basic integer math")
			)
		)
	)
	#endregion

	#region fit / fdescribe / fcontext
	describe("fit / fdescribe / fcontext — focus mode", func() -> void:
		it("normal it() examples run as usual when there are no focused items", func() -> void:
			expect(1 + 1).to(eq(2))
		)

		it("when ANY fit/fdescribe exists in the file, only focused items run", func() -> void:
			# This is the key behaviour: focus mode is file-scoped.
			# Uncomment the fit() below to activate focus mode for this entire file.
			expect(true).to(be_true())
		)

		describe("fit() — focus a single example", func() -> void:
			it("normal example — runs when focus mode is NOT active", func() -> void:
				expect(42).to(eq(42))
			)

			# Uncomment to activate focus mode (only this example runs in this file):
			# fit("focused example — only this runs when focus mode is active", func() -> void:
			#     expect(1).to(eq(1))
			# )
		)

		describe("fdescribe() — focus an entire group", func() -> void:
			it("all examples inside an fdescribe run in focus mode", func() -> void:
				expect(true).to(be_true())
			)
			it("examples OUTSIDE the fdescribe are skipped in focus mode", func() -> void:
				expect(true).to(be_true())
			)

			# Uncomment to activate focus mode (both examples above would run):
			# fdescribe("focused group", func() -> void:
			#     it("first focused example", func() -> void: expect(1).to(eq(1)))
			#     it("second focused example", func() -> void: expect(2).to(eq(2)))
			# )
		)

		describe("fcontext() — alias for fdescribe", func() -> void:
			it("fcontext behaves identically to fdescribe", func() -> void:
				expect(true).to(be_true())
			)

			# Uncomment to activate:
			# fcontext("when in focus mode", func() -> void:
			#     it("only this context's examples run", func() -> void:
			#         expect(true).to(be_true())
			#     )
			# )
		)

		describe("practical workflow", func() -> void:
			it("use fit/fdescribe during TDD to run only the test under development", func() -> void:
				# Step 1: change 'it' to 'fit' on the test you're working on
				# Step 2: run the file — only that test executes (fast feedback loop)
				# Step 3: change 'fit' back to 'it' when done
				expect(true).to(be_true())
			)

			it("focus mode is safer than using --filter because it is explicit and local to the file", func() -> void:
				expect(true).to(be_true())
			)
		)
	)
	#endregion
