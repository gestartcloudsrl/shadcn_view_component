# Classes and HTML attributes

From *[Embracing TailwindCSS classes and HTML attributes](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-embracing-tailwindcss-classes-and-html-attributes)*.

This is the article this repo implements most closely, and the one whose
patterns are easiest to reinvent badly.

## The `style` DSL is `cva`

**From the article.** Declare classes; never build them with string
interpolation.

```ruby
class UIKit::Button::Component < ApplicationComponent
  option :type, default: proc { "button" }
  option :variant, default: proc { :default }
  option :disabled, default: proc { false }

  style do
    base {
      %w[
        items-center justify-center px-4 py-2
        text-sm font-medium
        border border-slate-300 shadow-sm rounded-md
        focus:outline-none focus:ring-offset-2
      ]
    }
    variants {
      variant {
        primary { %w[text-white bg-blue-600 hover:bg-blue-700] }
        outline { %w[bg-slate-50 hover:bg-slate-100] }
      }
      disabled {
        yes { %w[opacity-50 pointer-events-none] }
      }
    }
    defaults { {variant: :primary, disabled: false} }
    compound(variant: :outline, disabled: true) { %w[opacity-75 bg-slate-300] }
  end

  erb_template <<~ERB
    <button type="<%= type %>" class="<%= style(variant:, disabled:) %>"<%= " disabled" if disabled %>>
      <%= content %>
    </button>
  ERB
end
```

Four constructs, and they map onto `cva` one-for-one: `base`, `variants`,
`defaults`, `compound`.

**This repo**, the same DSL against a real upstream component. Note the string
concatenation style — it exists because Tailwind scans source text, so a class
must never be split across a `\` line continuation:

```ruby
module Shadcn
  module Button
    class Component < ApplicationViewComponent
      default_tag :button
      slot_name :button

      style do
        base {
          "inline-flex shrink-0 items-center justify-center gap-2 rounded-md text-sm font-medium " \
          "whitespace-nowrap transition-all outline-none focus-visible:border-ring " \
          "disabled:pointer-events-none disabled:opacity-50"
        }

        variants {
          variant {
            default { "bg-primary text-primary-foreground hover:bg-primary/90" }
            ghost { "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50" }
            link { "text-primary underline-offset-4 hover:underline" }
          }

          size {
            default { "h-9 px-4 py-2 has-[>svg]:px-3" }
            sm { "h-8 gap-1.5 rounded-md px-3 has-[>svg]:px-2.5" }
            icon { "size-9" }
            # `send` is how the DSL takes variant names that are not valid Ruby
            # method names — the keys have to stay identical to the TSX ones.
            send(:"icon-sm") { "size-8" }
          }
        }

        defaults { { variant: :default, size: :default } }
      end
    end
  end
end
```

## `tailwind_merge` is not optional

**From the article.** Wire it once, as the postprocessor:

```ruby
class ApplicationComponent < ViewComponentContrib::Base
  include ViewComponentContrib::StyleVariants

  style_config.postprocess_with do |classes|
    TailwindMerge::Merger.new.merge(classes.join(" "))
  end
end
```

Without it, "the caller's `px-6` beats the component's `px-4`" is decided by the
order rules landed in the stylesheet, which is to say: not decided at all.

**This repo** does the same, through a helper named after shadcn's `cn()`, and
builds the merger at boot rather than lazily — two Puma threads racing on a lazy
`||=` would each build one and throw a warm cache away.

```ruby
style_config.postprocess_with { |classes| ShadcnViewComponent.cn(classes) }
```

It also caches the compiled string when there are no caller classes, which keeps
the library's own invariant strings out of a fixed-size LRU shared with
everything a caller varies:

```ruby
def css_classes(extra = nil)
  return compile_classes(extra) if extra.present?

  ShadcnViewComponent.class_cache.fetch_or_store([ self.class.name, style_variants ]) do
    compile_classes(nil)
  end
end
```

## Passing HTML attributes through

**From the article.** Take a bag of attributes and splat it onto the element —
this is `{...props}`.

```ruby
class UIKit::Input::Component < ApplicationComponent
  option :name

  option :html_attrs, default: proc { {} }
  option :input_attrs,
    default: proc { {} },
    type: -> { {autocomplete: "off", required: false}.merge(_1) }

  erb_template <<~ERB
    <input <%= tag.attributes(**input_attrs) %>>
  ERB

  def before_render
    input_attrs.merge({name:})
  end
end
```

With the contrib sugar, where `#dots` is named for JavaScript's spread:

```ruby
class UIKit::Input::Component < ApplicationComponent
  option :name

  html_option :html_attrs
  html_option :input_attrs, default: {autocomplete: "off", required: false}

  erb_template <<~ERB
    <input <%= dots(input_attrs) %>>
  ERB
end
```

```erb
<%= render UIKit::Input::Component.new(
  name: "name",
  input_attrs: {placeholder: "Enter your name", autocomplete: "on", autofocus: true}) %>
```

**This repo** takes everything unrecognised as the bag — `initialize(as: nil,
**attributes)` — so there is no `html_attrs:` key to remember, and renders the
root through one method:

```ruby
def render_element(body: nil, **defaults, &block)
  attrs = element_attributes(**defaults)
  return tag.public_send(tag_name, **attrs) if VOID_TAGS.include?(tag_name)

  content_tag(tag_name, block ? capture(&block) : body, attrs)
end
```

`as:` is the port of shadcn's `asChild`: render the same classes on a different
element.

## Merging

**This repo**, all of it — the article stops at "splat the bag", and everything
below is what a 1:1 port needed on top.

**Precedence, lowest to highest: the `data-slot` marker, then the component's
own defaults, then the caller.**

The caller winning is the whole point — it is what the spread does in every
shadcn component, where `{...props}` comes last. Getting this backwards is the
single easiest mistake in the file, because a plain `merge` reads naturally and
does the opposite of what you want.

```ruby
def element_attributes(**defaults)
  base = { "data-slot" => self.class.slot_name }.compact
  merged = merge_attributes(base, defaults, attributes)
  merged["class"] = css_classes(merged.delete("class"))
  merged.compact
end
```

Note the consequence for subclasses: **what a subclass passes to `super` is a
default, despite arriving as a keyword splat.** It ranks below the caller.

Three keys are *combined* rather than replaced:

```ruby
def merge_attributes(*hashes)
  hashes.compact.map { |hash| normalize_attributes(hash) }.reduce({}) do |acc, hash|
    hash.each do |name, value|
      case name
      when "data", "aria"
        acc[name] = (acc[name] || {}).merge(value || {})
      when "class"
        acc["class"] = [ acc["class"], value ].compact
      when "data-action"
        append_action(acc, value)
      else
        acc[name] = value
      end
    end
    acc
  end
end
```

`data-action` concatenates because Stimulus reads a space-separated list: a
caller adding an action must not silently disable the component's own. The
concatenation itself is deliberately dumb — it joins in the order the hashes
were merged, and does not deduplicate:

```ruby
def append_action(hash, value)
  hash["data-action"] = [ hash["data-action"], value ].compact.join(" ")
end
```

So a caller passing the component's own action a second time gets it twice in
the attribute. Deduplicating would mean parsing Stimulus's descriptor grammar,
which nothing here needs yet — but what a duplicated descriptor *does* at
runtime has not been tested, so do not assume it is harmless.

And the normalisation that has to happen first — Rails has two spellings for the
same attribute, and both must land in the same branch:

```ruby
def normalize_attributes(hash)
  hash.each_with_object({}) do |(key, value), normalized|
    name = key.to_s

    if name == "data" && value.is_a?(Hash)
      data = value.transform_keys(&:to_s)
      action = data.delete("action")

      append_action(normalized, action) if action
      normalized["data"] = data unless data.empty?
    elsif name == "data-action"
      append_action(normalized, value)
    else
      normalized[name] = value
    end
  end
end
```

Without it, `data: { action: … }` and `"data-action" => …` reach different
branches and the element gets the attribute twice — invalid HTML, and the
browser keeps the first, so one of the two actions never fires. This was a real
bug; see
[.claude/docs/decisions/04-bugs-fixed.md](../../../docs/decisions/04-bugs-fixed.md).

## CSS scoping, for the non-Tailwind case

**From the article**, for components with their own stylesheet rather than
utility classes — a deterministic class prefix derived from the component path,
generated on both sides:

```ruby
class << self
  def identifier
    @identifier ||= component_name.gsub("_", "-").gsub("/", "--")
  end
end

def class_for(name)
  "c--#{self.class.identifier}--#{name}"
end
```

```js
// postcss.config.js
module.exports = {
  plugins: {
    'postcss-modules': {
      generateScopedName: (name, filename, _css) => {
        const matches = filename.match(/\/app\/views\/components\/?(.*)\/index.css$/)

        if (!matches) return name

        const identifier = matches[1].replaceAll('_', '-').replaceAll('/', '--')

        return `c--${identifier}--${name}`
      },
      getJSON: () => {}
    }
  }
}
```

```erb
<div class="<%= class_for('container') %>">
  Hello World!
</div>
```

**Not used in this repo** — it is Tailwind throughout, and the port's classes
must match upstream's exactly — but it is the answer when a component needs real
CSS and you do not want a global class name.
