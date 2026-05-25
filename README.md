# GSpec

**Lightweight, RSpec-inspired unit testing for Godot 4.**

GSpec brings the expressive, readable style of [Ruby's RSpec](https://rspec.info) to GDScript. Write self-documenting specs with `describe`, `it`, and `expect` — then run them from the built-in editor panel or headless CLI. No scene setup required, no boilerplate.

```gdscript
extends GSpec

func spec() -> void:
    describe("SDamageProcessor", func() -> void:
        before_each(func() -> void:
            v["atk"] = build_entity({"physical_attack": 500})
            v["def"] = build_entity({"health": 10000})
        )

        it("always deals at least 1 damage on hit", func() -> void:
            var result: SDamageResult = SDamageProcessor.new(v["atk"], v["def"]).perform()
            expect(result.final_damage).to(be_gte(1))
        )

        it("never produces a dodge when accuracy is maxed", func() -> void:
            var result: SDamageResult = SDamageProcessor.new(v["atk"], v["def"]).perform()
            expect(result.hit_result).not_to(eq(SDamageConst.HitResult.DODGE))
        )
    )
```

---

## Features

- **RSpec DSL** — `describe`, `context`, `it`, `xit`, `fit`, `fdescribe`, `fcontext`
- **Lifecycle hooks** — `before_each`, `after_each`, `before_all`, `after_all`
- **Shared state** — `v` dictionary (cleared per example) and `let_def`/`get_let` (lazy + memoised)
- **Shared examples** — `shared_examples` / `it_behaves_like` for reusable test groups
- **Rich matcher library** — 20+ built-in matchers covering equality, comparisons, collections, types, properties, floats, and more
- **Custom matchers** — `satisfy(predicate)` as an escape hatch for any condition
- **State-mutation testing** — `change(observer).by(n)` / `.from(a).to(b)`
- **Test doubles** — lightweight spy/stub objects via `double()` + `have_received()`
- **Focus mode** — `fit`/`fdescribe` to run only the test you're working on
- **Editor panel** — collapsible tree output, click-to-navigate to failing tests
- **CLI runner** — headless execution with `--filter` and `--format` options
- **Zero dependencies** — pure GDScript, no external tools required

---

## Installation

### Via Godot AssetLib *(recommended)*
1. Open your project in the Godot editor
2. Go to **AssetLib** → search **GSpec**
3. Download and install
4. Enable the plugin: **Project → Project Settings → Plugins → GSpec ✓**

### Manual
1. Copy the `addons/godot_spec/` folder into your project's `addons/` directory
2. Enable the plugin: **Project → Project Settings → Plugins → GSpec ✓**

---

## Quick Start

**1. Create a spec file** anywhere in your project (convention: `res://spec/`):

```gdscript
# res://spec/system/damage/processor_spec.gd
extends GSpec

func spec() -> void:
    describe("SDamageProcessor", func() -> void:
        it("returns positive damage for a normal hit", func() -> void:
            var atk: SDamageState = SDamageState.new(build_attacker())
            atk.damage_type = SDamageConst.DamageType.PHYSICAL
            var result: SDamageResult = SDamageProcessor.new(atk, build_defender()).perform()
            expect(result.final_damage).to(be_gte(1))
        )
    )
```

**2. Run from the editor** — click the **GSpec** tab at the bottom of the editor, then **▶ Run All**.

**3. Run from the terminal:**

```bash
godot --headless res://addons/godot_spec/runner.tscn
```

---

## DSL Reference

### Structure

```gdscript
describe("ClassName", func() -> void:   # group related examples
    context("when condition", func() -> void:   # sub-group (alias for describe)
        it("does something", func() -> void:    # a single test
            expect(actual).to(eq(expected))
        )
        xit("work in progress")   # pending — counted but not run
        fit("only this runs", func() -> void: ...)   # focus mode
    )
    fdescribe("focused group", func() -> void: ...)  # all inside are focused
)
```

### Lifecycle Hooks

```gdscript
before_each(func() -> void:  # runs before every it() in this group
    v["entity"] = EntityResource.new()
)
after_each(func() -> void:   # runs after every it()
    cleanup()
)
before_all(func() -> void:   # runs ONCE before the first it() in this group
    _shared_config = load_config()   # use script-level vars for before_all state
)
after_all(func() -> void:    # runs ONCE after the last it()
    _shared_config = null
)
```

### Shared State

```gdscript
# v — mutable dict, cleared before every example
before_each(func() -> void:
    v["hp"] = 100
)
it("takes damage", func() -> void:
    v["hp"] -= 30
    expect(v["hp"]).to(eq(70))
)

# let_def — lazy + memoised per example
let_def("entity", func() -> Variant:
    return EntityResource.new()
)
it("uses entity", func() -> void:
    expect(get_let("entity")).not_to(be_null())
)
```

### Shared Examples

```gdscript
shared_examples("a damageable entity", func(max_hp: int) -> void:
    before_each(func() -> void:
        v["entity"] = build_entity({"health": max_hp})
    )
    it("starts with full health", func() -> void:
        expect(v["entity"].health).to(eq(max_hp))
    )
)

describe("Player", func() -> void:
    it_behaves_like("a damageable entity", [1000])
)
describe("Enemy", func() -> void:
    it_behaves_like("a damageable entity", [500])
)
```

### Expectations

```gdscript
expect(value).to(matcher)       # assert passes
expect(value).not_to(matcher)   # assert fails
```

---

## Matchers

### Equality
| Matcher | Passes when |
|---------|------------|
| `eq(expected)` | `actual == expected` |

### Boolean
| Matcher | Passes when |
|---------|------------|
| `be_true()` | `actual === true` (strict) |
| `be_false()` | `actual === false` (strict) |
| `be_null()` | `actual == null` |
| `be_truthy()` | GDScript-truthy (non-zero, non-empty) |
| `be_falsy()` | GDScript-falsy (null, 0, "", [], {}) |

### Comparisons
| Matcher | Passes when |
|---------|------------|
| `be_greater_than(n)` | `actual > n` |
| `be_less_than(n)` | `actual < n` |
| `be_gte(n)` | `actual >= n` |
| `be_lte(n)` | `actual <= n` |
| `be_between(low, high)` | `low <= actual <= high` |
| `be_close_to(n, delta=0.001)` | `abs(actual - n) <= delta` |

### Collections
| Matcher | Passes when |
|---------|------------|
| `include(value)` | Array/Dictionary/String contains value |
| `be_empty()` | Array/Dictionary/String has size 0 |
| `have_size(n)` | Array/Dictionary/String has size n |
| `contain_exactly([...])` | Array has exactly these elements (any order) |
| `match_dict({...})` | Dictionary contains all expected key-value pairs |
| `all(matcher)` | Every element in Array satisfies matcher |

### Type & Properties
| Matcher | Passes when |
|---------|------------|
| `be_instance_of(Type)` | `actual is Type` |
| `have_property("name")` | Object has the property |
| `have_property("name", value)` | Property exists and equals value |
| `have_attributes({...})` | All key/value pairs match object properties |

### Custom
| Matcher | Passes when |
|---------|------------|
| `satisfy(func(x): return bool, "description")` | Predicate returns true |
| `change(observer).by(n)` | Action changes observed value by n |
| `change(observer).to(v)` | Action changes observed value to v |
| `change(observer).from(a).to(b)` | Value transitions from a to b |

---

## Test Doubles

```gdscript
it("records method calls", func() -> void:
    var d: SpecDouble = double("MyService")
    d.stub("compute", 42)                  # configure return value

    var result: int = d.track("compute", [10, 0.5]) as int   # production code calls this

    expect(result).to(eq(42))
    expect(d).to(have_received("compute"))
    expect(d).to(have_received("compute").times(1))
    expect(d).to(have_received("compute").with([10, 0.5]))
    expect(d.get_call_count("compute")).to(eq(1))
)
```

> **Note:** GDScript does not support dynamic method interception. Production code must call `double.track("method", args)` explicitly in place of the real call.

---

## Editor Panel

Enable the plugin and look for the **GSpec** tab at the bottom of the editor.

| Button | Action |
|--------|--------|
| **▶ Run All** | Discovers and runs all `*_spec.gd` files under `res://spec/` |
| **▶ Run Current File** | Runs the spec file open in the script editor |
| **Filter** | Case-insensitive substring match on test names |

Results appear as a collapsible tree. Click any item to jump to its source line. Failed groups expand automatically.

---

## CLI Usage

```bash
# Run all specs (auto-discover res://spec/)
godot --headless res://addons/godot_spec/runner.tscn

# Run a single file
godot --headless res://addons/godot_spec/runner.tscn -- res://spec/system/damage/processor_spec.gd

# Filter by name (case-insensitive substring match)
godot --headless res://addons/godot_spec/runner.tscn -- --filter "crit"

# Dot format (compact)
godot --headless res://addons/godot_spec/runner.tscn -- --format dot

# Combine options
godot --headless res://addons/godot_spec/runner.tscn -- --format doc --filter "damage" res://spec/my_spec.gd
```

Exit code is `0` when all tests pass, `1` on any failure.

---

## Project Structure

```
addons/godot_spec/
├── core/            # Framework internals (GSpec, SpecRunner, SpecGroup…)
├── matchers/        # Built-in matcher classes
├── formatters/      # CLI output formatters (doc, dot)
├── editor/          # Editor panel and formatter
├── spec/            # Addon self-tests
│   └── examples/    # Living documentation / usage examples
├── plugin.cfg
├── plugin.gd
├── run.gd           # CLI entry point
└── runner.tscn      # CLI scene
```

---

## Inspiration

GSpec is directly inspired by [RSpec](https://rspec.info), the beloved testing framework for Ruby on Rails. The goal was to bring that same expressive, human-readable style of writing tests into the Godot ecosystem — without the weight of a full test harness.

If you know RSpec, GSpec will feel immediately familiar. If you don't, the examples above are all you need.

---

## License

MIT — see [LICENSE](LICENSE).
