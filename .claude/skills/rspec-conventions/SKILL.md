---
name: rspec-conventions
description: Conventions for writing RSpec specs — structure, naming, let/subject, doubles, matchers — distilled from Better Specs, the RSpec Style Guide and the ruby/spec style guide, with the places this repo deliberately departs from them. Use whenever creating or modifying a *_spec.rb file, a spec support file, or spec configuration (.rspec, spec_helper, the RSpec cops in .rubocop.yml).
---

# RSpec conventions

A summary of [betterspecs.org](https://www.betterspecs.org/),
[rspec.rubystyle.guide](https://rspec.rubystyle.guide/) and the
[ruby/spec style guide](https://ruby.github.io/rubyspec.github.io/style_guide/).
Where the three disagree, the disagreement is named rather than papered over.

The bad/good code behind these rules lives in `references/`, split three ways so
you open one file rather than all of it — [structure](references/structure.md),
[setup](references/setup.md), [expectations](references/expectations.md), indexed
in [references/README.md](references/README.md). Read the relevant one when a
rule is not obvious from its one-line statement, or when you are about to argue
with one.

## Structure

[Examples: structure.md](references/structure.md)

- **`describe` the method, not a sentence about it.** `.authenticate` for a class
  method, `#admin?` for an instance method. Nested constants read `Super::Sub`.
- **Conditions go in `context`, never in the example description.** A description
  ending in "if…", "when…" or "unless…" is a context waiting to be extracted.
- **Context descriptions start with `when`, `with` or `without`**, so the nested
  descriptions concatenate into a sentence.
- **Give a context its opposite.** A lone `when logged in` with no `when logged
  out` is a case you have not thought about yet.
- **Declaration order:** `subject`, then `let!`/`let`, then `before`/`after`,
  then nested `describe`s. One blank line between groups and around examples;
  none straight after a `describe` opens.
- **Cover the equivalence classes and the boundaries**, not just the happy path —
  found, not found, not owned; empty, one, many.

## Naming

[Examples: structure.md](references/structure.md)

- **No "should".** Third person present: `returns`, `creates`, `does not change`.
- **Keep descriptions under ~60 characters.** A long one usually means the setup
  is doing work the description is trying to explain.
- **`it` when there is a description or a one-liner; `specify` when there is
  none.** `it` with no description reads wrong.
- **Use `described_class`** rather than repeating the class name.

## Data and setup

[Examples: setup.md](references/setup.md)

- **`let` over instance variables.** `let` is lazy and memoised per example;
  `@ivar` in a `before` is eager and easy to leave dangling. `let!` when the
  thing must exist whether or not an example names it.
- **`let` over `def` for anything that is a value.** A reader like
  `def trigger = find("[data-slot=x]")` is a `let` written the long way round.
  `def` in an example group is reserved for helpers that **take arguments**,
  which `let` cannot express — `def token(name)`, `def audit(within: nil)`. If
  it takes no arguments, it is a `let`.
- **But do not convert a reader that is called across a state change.** `let`
  memoises for the whole example, so a helper read *before and after* a click —
  `states`, `value`, `selected` — returns its first answer the second time and
  the assertion silently stops testing anything. Those stay methods, or become
  a `let` holding a lambda. This is the one case where `def` is not the lazy
  option but the correct one, and it is why the rule above is about values
  rather than about `def`.
- **Don't wrap trivial primitives in `let`.** `let(:name) { "x" }` used once is
  indirection, not DRY.
- **Name the subject when you refer to it** — `subject(:article)`. Leave it
  anonymous only for `is_expected` one-liners.
- **Give differently-configured subjects different names across contexts**, so a
  reader can see which one an example means.
- **Create only the data the example needs.** Three records where the assertion
  is about two is setup nobody will dare delete later.
- **Avoid `before(:context)` / `:all`.** State leaks between examples and the
  failure surfaces somewhere else. Omit `:each`/`:example` — it is the default.
- **No incidental state.** An example must not depend on another having run;
  assert transitions with `expect { … }.to change { … }`.
- **Prefer `stub_const` to declaring a class or constant inside an example
  group** — a bare `CONST = …` in a `describe` block lands on `Object`.
- **Duplication first, extraction second.** Pull a value into `let` or a shared
  example once it repeats, not in anticipation. Clarity beats brevity: a spec is
  read when it fails, out of context.

## Doubles and stubs

[Examples: setup.md](references/setup.md)

- **Test real behaviour where you can.** Mock the boundary, not the thing under
  test.
- **Never stub the subject.** If the object needs a method stubbed to be
  testable, construct it differently.
- **Verifying doubles only** — `instance_double`, `class_double`,
  `object_double`. Leave `verify_partial_doubles` on.
- **Never `allow_any_instance_of` / `expect_any_instance_of`.** Inject the
  dependency instead.
- **Stub outbound HTTP** (webmock/VCR). A suite that reaches the network is not
  a suite.
- **Travel time, don't stub it.** Freeze the clock with a time helper rather
  than stubbing methods on `Time` or `Date`.

## Matchers

[Examples: expectations.md](references/expectations.md)

- **`expect(…).to`, never `.should`.** Configure `syntax = :expect` so the old
  form cannot come back.
- **`is_expected.to` for one-liners**, not the bare `should`.
- **Predicate matchers:** `expect(user).to be_admin`, not
  `expect(user.admin?).to be true`.
- **Never bare `be`** — it passes on anything truthy. Say `be_truthy`, `be_nil`,
  `eq`, or a type-specific matcher.
- **Use the built-in matcher instead of calling the method yourself:** `include`,
  `match`, `start_with`, `have_attributes`.
- **`expect { … }.to raise_error SomeClass` — the class, not the message.**
  Messages are free to change and to be translated. Same for block expectations
  generally: write the block at the expectation, don't hide it in a subject.
- **Capybara negatives:** `have_no_selector`, not `to_not have_selector` — the
  first waits for absence, the second races.
- **Extract a custom matcher** once the same multi-line assertion appears in
  several places.

## Where this repo departs

Three deliberate divergences. The reasoning is in
[.claude/docs/decisions/03-testing.md](../../docs/decisions/03-testing.md) and
the `RSpec/*` section of [.rubocop.yml](../../../.rubocop.yml).

1. **One expectation per example does not apply to system specs.** An example
   there is one user journey — open the dialog, tab through it, press Escape —
   and each step is worth asserting where it happens. `MultipleExpectations` and
   `ExampleLength` are off. In component and unit specs, still keep to one
   behaviour per example.

2. **Examples generated in a loop are allowed when the list comes from disk.**
   The style guide says never; `parity_spec`, `snapshot_spec`, `previews_spec`
   and `accessibility_spec` all do it, so that adding a preview or vendoring a
   new TSX creates its example automatically. The list is read into a **local**,
   not a constant, because it has to exist when the group is defined — which is
   why `LeakyLocalVariable` is off. Do **not** use this for a handful of
   hand-written cases; write those out.

3. **No factories, no fixtures, no database.** This gem has neither ActiveRecord
   nor FactoryBot. The test data is components and the Lookbook preview
   templates, which double as the fixture set — adding a preview is what gets a
   component covered by the snapshot, preview and accessibility specs.

Also note: the ruby/spec guide bans `context` outright and requires `describe`
everywhere. That is a house rule for mspec and the Ruby language suite. It does
**not** apply here — use `context`, as the other two guides say.

## Before finishing

- Pick the right file: `parity_spec` for upstream classes, `snapshot_spec` for
  rendered HTML, `stimulus_contract_spec` for Ruby↔JS wiring, `spec/system` for
  behaviour. The table in [CLAUDE.md](../../../CLAUDE.md) says which proves what.
- Run the spec you touched, then `bin/rubocop`.
- Never describe a spec as proving more than it does. A rendered-HTML diff is
  not a behaviour test; axe is not a screen reader.
