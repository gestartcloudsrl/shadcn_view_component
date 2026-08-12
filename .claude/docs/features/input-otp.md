# Input OTP

*Adapted: 1:1 in markup, rebuilt on the one input the package is built on.*

`input-otp.tsx` wraps the **input-otp** package, and this port does not. Of its
715 lines, the shadcn component uses the root and, per box, three values:

| | |
|---|---|
| `char` | `value[i]`, or nothing |
| `isActive` | focused, and `i` is where the selection is |
| `hasFakeCaret` | active and empty |

The rule behind them is six lines (`input.tsx:596-618`). What is underneath is
the idea worth taking: **one real `<input>` lying over the boxes**. Typing,
paste, backspace, the arrow keys, and the one-time-code autofill a phone offers
from a message are all the browser's, because the field the browser sees is an
ordinary input. What is left is painting, and that is this port's controller.

## The technique, which is not in the TSX

`input-otp.tsx` gives the input one class — `disabled:cursor-not-allowed` — and
everything that makes it work comes from the package as inline styles. Read
from the rendered demo, not from the source, and reproduced as a rule in
`shadcn.css` keyed on the `data-slot`:

```
position:absolute; inset:0; width:100%; height:100%;
opacity:1; color:transparent; caret-color:transparent; background:transparent;
letter-spacing:-0.5em; font-size:<the boxes' height>; font-family:monospace
```

`opacity: 1` is the load-bearing one. The input is **real and opaque** — hidden
or `opacity:0`, and neither a password manager nor an SMS autofill will offer
anything. What is invisible is its text and its caret. The negative letter
spacing stops the value reaching past the boxes; the font size is the boxes'
own height, read by the controller, so a native selection paints across them
rather than across a line of text of some other size.

## Two behaviours worth naming

**The selection is clamped.** On focus and after every change the package sets
it to `min(value.length, maxLength - 1) … value.length` (`input.tsx:432, 472`).
Without it a complete code leaves the caret past the last box and *no* box is
active, so a finished code looks abandoned.

**`onComplete` is an event.** Upstream takes a callback; a callback has no
markup. `shadcn--input-otp:complete` carries the value, and whether that means
submitting the form is the app's decision rather than this component's.

## What is not reproduced

- **The browser workarounds.** Twenty-one of the package's lines name Safari,
  iOS, a password manager or a selection quirk. None is ported, because none can
  be ported by reading — each answers a device this repository cannot run. If a
  code field misbehaves on iOS, that is where to look first.
- **`pushPasswordManagerStrategy`**, which moves a password manager's badge out
  of the way of the boxes.
- **`placeholder`** and `pattern` as component arguments. The pattern is the
  input's own attribute and is passed through `input:`, along with anything else
  a caller wants on it — this port has one input and hands over its keys rather
  than inventing an argument per attribute.
- **A per-slot `index`.** Upstream takes one; this reads the boxes in the order
  they appear, which is the same answer without a number for a caller to get
  wrong.

## Naming the field

There is one input, and it takes a name the way any input does — a `<label
for>` against an `id` passed through `input:`, or an `aria-label`. Nothing in
the component supplies one, upstream's does not either, and an unlabelled one
fails axe. Both previews label it; the default one does it with a real label,
which is what a form should do.
