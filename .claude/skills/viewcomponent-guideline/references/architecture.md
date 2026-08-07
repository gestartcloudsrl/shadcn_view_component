# Architecture

From *[Building modern Rails frontends](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-building-modern-rails-frontends)*.

## Sidecar layout

**From the article.** One directory per component, holding everything that
component needs:

```
components/
  example/
    component.rb
    component.html.erb
    preview.rb
    styles.css
    whatever.png
```

The unit of organisation is the component, not the file type. Moving or deleting
a component is one `mv` or one `rm -r`.

**This repo** puts them under `app/components/shadcn/<family>/<part>/` — same
idea, different root, because a Rails engine gets `app/components` as an
autoload root for free and the `shadcn/` nesting keeps `Card` and `Table` out of
a host app's top-level namespace.

## A part with no behaviour gets no file

**This repo.** Most of shadcn's sub-components are a single element with a
`data-slot` and a fixed set of classes — `CardTitle` is a `<div>` with two.
Writing each as its own file meant thirteen lines of module nesting around one
string, so they are declared on the family module instead:

```ruby
# @param name [Symbol] the part, snake_case; `:group_count` becomes `GroupCount::Component`
# @param slot [String] the `data-slot` shadcn stamps on it
# @param classes [String] its base classes
# @param tag [Symbol] the element, when it is not a `<div>`
# @param from [Class] a part to specialise instead of building a new one
part(name, slot:, classes: nil, tag: nil, from: ApplicationViewComponent)
```

A whole family then reads at a glance, and the class strings stay literal —
which is what both the parity spec and Tailwind's scanner need:

```ruby
# app/components/shadcn/card.rb — a sibling of card/, not inside it
module Shadcn
  module Card
    extend Parts

    part :action, slot: "card-action",
                  classes: "col-start-2 row-span-2 row-start-1 self-start justify-self-end"

    part :content, slot: "card-content", classes: "px-6"

    part :description, slot: "card-description", classes: "text-sm text-muted-foreground"

    part :title, slot: "card-title", classes: "leading-none font-semibold"
  end
end
```

**A part earns its own `component.rb` as soon as it has** variants, slots, extra
markup, or attributes computed from its arguments. Until then it is a line.

## Pass components, not arguments

**From the article.** When a child needs data the parent does not have, the
answer is a slot, not another keyword argument threaded through three levels:

```ruby
# app/views/components/feed/component.rb
class Feed::Component < ApplicationViewComponent
  renders_one :pinned
  renders_many :posts
end
```

```erb
<%# app/views/components/feed/component.html.erb %>
<%= pinned %>

<% posts.each do |post| %>
  <%= post %>
<% end %>
```

```erb
<%= render(Feed::Component.new) do |c| %>
  <% c.with_pinned do %>
    <%= render(Post::Component.new(@pinned_post)) %>
  <% end %>

  <% @posts.each do |post| %>
    <% c.with_post do %>
      <%= render(Post::Component.new(post)) %>
    <% end %>
  <% end %>
<% end %>
```

> Whenever a child component has data requirements that are different from its
> parent, it almost always means that it should be passed down as a component
> instead of being hardcoded in the parent component's template.

**This repo** uses `renders_one` the same way — `Dialog::Content` declares
`renders_one :header` and `:footer`. One trap that is ours, not the article's:
**slot content renders before block content**, so mixing the two in one parent
reorders the output. The select and dropdown previews render their items in the
block for exactly this reason.

## Context for genuinely global state

**From the article.** Threading `current_user` through every component is worse
than the coupling it avoids. Set it once, read it where needed, using
`dry-effects`:

```ruby
# ApplicationController
include Dry::Effects::Handler.Reader(:current_user)

around_action :set_current_user

private

def set_current_user
  with_current_user(current_user) { yield }
end
```

```ruby
# ApplicationViewComponent
include Dry::Effects.Reader(:current_user, default: nil)
```

**This repo does not do this**, and the reason generalises: a library has no
`current_user`, and adding `dry-effects` would put a dependency in every host
that installs the gem. Context is an application pattern.

## Atomicity, and the two kinds of component

- One responsibility per component. A ~100-line template is a decomposition
  signal.
- **General-purpose (presentational)** components know nothing about your
  models. They are the palette.
- **App-specific (container)** components use the palette with domain objects.
  If it accepts an `ActiveRecord` object, it is one of these.

Keeping the two apart is what makes the first kind reusable across an
application — and, in this repo's case, across applications nobody has seen.

## No database queries in components

> Views are for *rendering* data, not *fetching* it.

Fetch in the controller, preload associations, pass the result down. A component
that queries is a component that will N+1 the moment someone renders it in a
loop. [tooling.md](tooling.md#the-query-linter) has a runtime linter that turns
this from a convention into a failure.

## Testing

Test the rendered output. The Ruby methods are private helpers; the template is
the public interface.

**From the article:**

```ruby
describe Menu::Component do
  subject { page }

  let(:component) { described_class.new }

  before do
    with_current_user(user) { render_inline(component) }
  end

  context "when current_user is present" do
    let(:user) { build(:user, name: "Handsome") }

    it "renders sign out button" do
      is_expected.to have_link "Sign out"
    end

    it "has greeting text" do
      is_expected.to have_content "Hello, Handsome!"
    end
  end

  context "when current_user is absent" do
    let(:user) { nil }

    it "renders sign in button" do
      is_expected.to have_link "Sign in"
    end
  end
end
```

> We don't make assertions for the exact markup — there's no point. Instead,
> we're interested in the same things as when writing any other unit test:
> conditional logic and calculations.

For anything that only happens in a browser, drive the preview — **from the
article:**

```ruby
# spec/system/components/my_component_spec.rb
it "does some dynamic stuff" do
  visit("/rails/view_components/my_component/default")
  click_on("JavaScript-infused button")

  expect(page).to have_content("dynamic stuff")
end
```

**This repo** does exactly that, through Lookbook's URL scheme rather than
ViewComponent's, wrapped in one helper so the scheme is named in one place:

```ruby
def visit_preview(family, example = :default)
  visit "/lookbook/preview/shadcn/#{family}/#{example}"
  expect(page).to have_css("[data-controller]", visible: :all, wait: 5)
end
```

**Testing a prop that changes the element**, which the article does not cover
because it has no `asChild`. The assertion is about the tag, so it needs both
halves — that the new element is there *and* that the default one is gone:

```ruby
context "with as:" do
  it "renders the given element instead of the default" do
    render_inline(described_class.new(as: :a, href: "/x"))

    expect(page).to have_css("a[data-slot=button][href='/x']")
    expect(page).to have_no_css("button")
  end
end
```

Its component specs follow the article's rule with one exception worth knowing:
asserting a *class string* is legitimate here, because the whole point of the
port is that a given variant emits exactly the classes upstream emits. See
[.claude/docs/decisions/03-testing.md](../../../docs/decisions/03-testing.md).
