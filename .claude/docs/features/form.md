# Form

*Ours: the family is a Rails FormBuilder rather than a set of components, and
this is a decision rather than a gap.*

`form.tsx` is 167 lines of which almost none is markup. Five of its seven
exports are wrappers whose whole job is to read one context — `useFormField` —
and stamp an id, an `aria-describedby`, an `aria-invalid` and an error string
onto something. The context comes from **react-hook-form**: `Form` *is*
`FormProvider`, and `FormField` *is* its `Controller`. Neither renders any DOM.

That state has no counterpart on a server, and the job the wrappers do with it
is exactly what `ActionView::Helpers::FormBuilder` already does with a model.
So this family is `ShadcnViewComponent::FormBuilder`, built over the `Field`
components — which is also what upstream's own newer form examples are built
on.

## Part by part

| `form.tsx` | here | |
|---|---|---|
| `Form` (= `FormProvider`, no DOM) | `shadcn_form_with` | renders the `<form>`; upstream's renders nothing and the app writes its own |
| `FormField` (= `Controller`) | — | field-level client state; nothing to port |
| `FormItem` (`grid gap-2`) | `Shadcn::Field::Component`, via `f.shadcn_field` | |
| `FormLabel` | `Field`'s label slot | |
| `FormControl` (a Slot) | `#control_options` | same three attributes, put on the control directly |
| `FormDescription` | `Field`'s description slot | |
| `FormMessage` | `Field`'s error slot | |
| `useFormField` | — | the hook the five wrappers exist to call |

## The divergences

**1. The `data-slot` names are `field-*`, not `form-*`.** Upstream emits
`form-item`, `form-label`, `form-control`, `form-description` and
`form-message`; nothing here emits any of them. This is the one place the port
gives up 1:1 on markup outright, and it is the direct consequence of building
on `Field`: a host styling `[data-slot="form-message"]` from an upstream
snippet will not match anything. `parity_spec` does not check this family at
all — see `ported_as_a_form_builder` there — because a class comparison would
only restate the same sentence.

**2. Validation state arrives after a round trip, not as you type.** Upstream's
error comes from react-hook-form's resolver, so it appears and clears while the
field is being edited. Here it comes from `ActiveModel::Errors`, so a field is
valid until the server says otherwise. Everything downstream of that —
`aria-invalid`, `data-invalid` on the `Field`, whether the error element exists
— follows the same timing. An app that wants live validation has to bring its
own; nothing in this gem prevents it, and nothing in this gem provides it.

**3. One error upstream, all of them here.** `FormMessage` renders
`String(error?.message ?? "")` — a single string. `ActiveModel::Errors` gives an
array per attribute, and `Field`'s error slot takes the array, so a field
failing three validations shows three messages.

**4. `aria-describedby` names only elements that exist — since this file was
written, and not before.** Upstream sets it unconditionally to the description
id, and to the description *and* message ids when there is an error, whether or
not a `FormDescription` was ever rendered (`form.tsx:113-119`). A field with no
description therefore ships an `aria-describedby` naming an id that is not in
the document: invalid ARIA, resolving to nothing, so the control claims a
description it does not have.

This was first written up here as a divergence in the port's favour. It was not
one — checking the claim showed `#control_options` doing exactly the same thing,
for every field without a description and for every control rendered outside a
field. `#shadcn_field` now records whether it rendered a description and the
control references the id only then, with three examples in
`spec/form_builder_spec.rb` holding it. Worth leaving the history in: the claim
was plausible, the code was two lines away, and it took writing the sentence
down to look.

**5. The ids are Rails'.** Upstream derives everything from one `React.useId()`:
`«id»-form-item`, `«id»-form-item-description`, `«id»-form-item-message`. Here
they are `field_id(method)` and that plus `_description` / `_error` / `_label`,
so they are stable across renders, predictable from the model and attribute
name, and the same ids Rails' own helpers would produce. This is the standing
rule — upstream wins on markup, Rails wins on API — applied to the one thing a
form is addressed by.

**6. A control that carries an ARIA role is named by `aria-labelledby`.**
Upstream's `FormLabel` sets `htmlFor` and stops there. Select, Checkbox and
Switch here render a `<button>` with a role, and `<label for>` does not name a
button — `role="combobox"` cannot take its name from its content either — so
the builder points those at the label's own id instead. Without it they reach
the browser unnamed, which `spec/system/accessibility_spec.rb` catches. This is
an addition, not a substitution: the `for`/`id` pair is still there.

**7. `f.shadcn_select` has no browser validation.** It submits through a hidden
input, so `required` will not stop the form. `f.shadcn_native_select` is a real
`<select>` and does — prefer it unless the styled listbox is the point. Upstream
has the same split and the same consequence; it is repeated here because a Rails
app is likelier to reach for `required:` and expect it to hold.

## What has no equivalent, and is not missing

`FormField`, `useFormField`, and `Form` itself. All three exist to move
react-hook-form's per-field state around a React tree. There is no state to
move: the values come from the model, the errors come from the model, and the
ids come from the attribute name.
