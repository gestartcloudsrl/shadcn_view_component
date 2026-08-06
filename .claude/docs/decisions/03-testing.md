# Testing decisions

What each spec is for, what it deliberately does *not* prove, and which
approaches were measured and rejected.

## The parity spec was theatre

Two council members proved it by mutating code that stayed green. It compares
token *sets per family*, so a class sitting in a comment counted as ported, and
swapping two variants' bodies passed cleanly.

Three responses, in order of value:

1. **`snapshot_spec.rb`** — golden HTML for every preview. Catches wrong part,
   wrong variant, attribute drift, extra classes. Verified against a real variant
   swap: parity passes, snapshots fail.
2. **Ripper instead of a regex** for the Ruby side of parity, so a class in a
   comment can no longer count as ported.
3. **The README claim was corrected.** Overstating what a test proves is worse
   than the gap itself.

Parity still runs **one way**: when upstream removes a class the port keeps it
and nothing fails.

## The reverse parity check was rejected

Classes-the-port-has-that-upstream-doesn't was measured first: 12 of 13 families
came back dirty with false positives — Ruby constant names, icon names, slot
names, legitimate composition where one family reuses another's parts. It would
have needed exactly the exception tables that were being criticised in the first
place. Snapshots cover the same ground properly.

## `stimulus_contract_spec.rb`

The best coverage-per-line in the repo. Ruby and JS are wired together by bare
strings, so renaming a controller method breaks every Select in the wild with
nothing failing. Static analysis of the JS, not execution of it.

## System specs

The only place the JavaScript executes. Previews double as fixtures, which is why
adding a preview is what gets a component covered.

Two of the fixed bugs were deliberately re-introduced to confirm the specs catch
them.

Three things to know before writing one:

- The gallery layout carries its own ModeToggle and ThemeSelector, so a preview's
  dropdown or select is **not** the only one on the page.
- Clicking an overlay element does not work — Selenium aims at its centre, which
  is where the dialog sits. `click_outside` clicks a viewport corner instead.
- Turbo paints the cached snapshot before the fresh body; asserting during that
  preview is a race. `wait_for_turbo` waits for the `data-turbo-preview` marker
  to clear. One spec was flaky 1-in-5 before this.

## axe

Runs over every family, at rest and with each layer open, plus contrast in dark
mode. Worth remembering: three of the first 13 "failures" were my own spec bugs —
the rule is `color-contrast` not `color_contrast`, and `button` had no `default`
preview. **A red axe run is not automatically a product bug.**

The genuine finding was that Select, Checkbox and Switch had no accessible name;
see [bugs-fixed](04-bugs-fixed.md).

## What is still unverified

- Parity in the removal direction (above).
- A screen reader. axe covers names, roles, required parents and contrast; it
  does not say whether the experience makes sense in VoiceOver or NVDA.
