# Examples behind the rules

The bad/good code for [SKILL.md](../SKILL.md), from
[betterspecs.org](https://www.betterspecs.org/) (**BS**) and
[rspec.rubystyle.guide](https://rspec.rubystyle.guide/) (**SG**). Split by the
question you are asking when you reach for it — open the one file, not all three.

| | |
|---|---|
| [structure.md](structure.md) | blank lines and declaration order, conditions belong in a `context`, `when`/`with`/`without`, opposing contexts, `.class_method` / `#instance_method`, no "should", short descriptions, `it` vs `specify` |
| [setup.md](setup.md) | `let` over `@ivar`, `let` to remove repetition, named subjects, not stubbing the subject, hook scope, incidental state, leaking constants, shared examples, verifying doubles, `allow_any_instance_of`, stubbing HTTP |
| [expectations.md](expectations.md) | one expectation or several, `aggregate_failures`, `expect` vs `should`, `is_expected`, predicate and built-in matchers, bare `be`, block expectations, custom matchers |

The snippets are verbatim, so they use single quotes and `FactoryBot.create(:article)`.
This repo uses double quotes (omakase) and has neither ActiveRecord nor
FactoryBot — read those lines as "some object under test".

## Left out on purpose

- **SG's "avoid `it` in iterators"** — its `good` version writes out three
  near-identical `describe` blocks by hand. Four specs here generate examples
  from a directory listing so that a new preview or a newly vendored TSX gets
  covered without anyone editing a spec. Departure 2 in SKILL.md.
- **BS's "use factories, not fixtures" and "create only the data you need"**, and
  SG's Rails model section (validity, `errors[:attr].size`, `another_object`) —
  this gem has no ActiveRecord and no FactoryBot; there is no record to build.
- **SG's Rails view, controller and mailer sections** — nothing here to apply
  them to.
- **BS's Guard, Zeus/Spork and Fuubar entries** — tooling around the suite, not
  rules for writing one.
- **The [ruby/spec style guide](https://ruby.github.io/rubyspec.github.io/style_guide/)
  snippets** (`should_be_close`, `:shared => true`) — mspec's API, not RSpec's,
  and its `should` form contradicts the expect-syntax rule. Its two rules that do
  carry over are in SKILL.md: assert the exception *class*, never the message,
  and `.class_method` / `#instance_method` in descriptions. Its ban on `context`
  is an mspec house rule and does not apply.
