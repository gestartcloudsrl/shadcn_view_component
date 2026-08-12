# Toaster

*Ours. Not adapted, not 1:1 — there is nothing here to be 1:1 with.*

`sonner.tsx` is forty lines and emits **no `data-slot` at all**. It hands a
theme, five icons and four custom properties to the `sonner` package, and every
element and every rule after that belongs to the package: 1,601 lines of
TypeScript and 729 of CSS, none of which is in `vendor/shadcn/`.

So this is the one family where "port it" would have meant *writing* a
component rather than reproducing one, and the decision was the owner's rather
than mine. `parity_spec` holds it in `ported_as_ours` and checks nothing;
`reverse_parity_spec` lists every class it renders, one by one, so that the
only component with no upstream is not also the only one nobody checks.

## What was kept from upstream

Its measurements, read from sonner's own stylesheet and source rather than
guessed: **356px** wide, **14px** between, **24px** from the edge, **four
seconds** of life, a 13px face, 16px of padding and a `0 4px 12px rgba(0,0,0,.1)`
shadow. And the four colours `sonner.tsx` itself chooses, which are the
popover's: its background, its foreground, the border and the radius.

The stacking is sonner's too, and it is the component's identity rather than a
flourish. Collapsed, the newest toast is at the front at its own height and each
one behind it is lifted by a gap, scaled down a twentieth per place, and has its
contents faded out — so a stack reads as one toast with others behind it.
Under the pointer it fans out: each returns to its own height and is lifted past
the ones in front of it, and the box a pointer has to stay inside grows with
them. That was missing from the first version — it piled them in a column — and
was reported.

## What is Rails' rather than sonner's

sonner has one way in: `toast()`, a function you import. This has three, in the
order an app will use them:

| | |
|---|---|
| **flash** | `Toaster::Component.new(flash:)` renders each as a toast, mapping `:notice` and `:alert` to the two variants `redirect_to` produces without being asked |
| **Turbo Stream** | `turbo_stream.append "shadcn-toasts", …` — the list has a stable id for exactly this |
| **JavaScript** | `document.dispatchEvent(new CustomEvent("shadcn--toast", { detail: … }))` |

The first two work because a toast is a real component and the controller
**watches the list** rather than being called. A `turbo_stream.append` knows
nothing about this controller and should not have to.

An event rather than an imported function for the third, because a Rails app has
no bundler step to import into.

## Three deliberate differences from sonner

**The close button is always visible.** sonner reveals its own on hover, which
it can afford because a toast there is also dismissed by swiping. There is no
swipe here, so the button is the only way out — and a control that appears on
hover is not a control on a phone.

**No swipe-to-dismiss, no promise toasts, no `richColors`, no positions per
toast.** The stack, the clock, the pause on hover and the five variants are
what is here.

**The list's height is not animated.** It is the area a pointer has to be inside
for the stack to stay open, and an area that arrives four hundred milliseconds
late is wrong exactly while it matters. The toasts animate; the box does not.
Measured in a browsing context that runs no animation frames, a transition here
left it at zero permanently.

## Two things the specs caught that reading did not

`Number(x) || fallback` reads a `0` as *not given* and returns the default —
the opposite of what `duration: 0` means here, which is *no clock*. The same
slip was in both routes, and it was found by looking at a page: three toasts
raised with `duration: 0` had all gone by the time the screenshot was taken.

And a `role` on an `<li>` replaces its implicit `listitem`, so an `<ol>` of
toasts with `role="status"` is a list axe fails and a screen reader miscounts.
sonner sets no role on its toasts either — the announcement comes from the
region's `aria-live`, and the region is a `<section>` because `aria-label` on a
bare `<div>` is prohibited ARIA.
