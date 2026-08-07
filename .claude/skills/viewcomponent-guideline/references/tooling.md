# Tooling

From *[Supercharging your components](https://evilmartians.com/chronicles/viewcomponent-in-the-wild-supercharging-your-components)*.

## `view_component-contrib`

The gem the whole approach rests on: base classes, sidecar previews, and the
StyleVariants plugin. **From the article**, install with

```sh
rails app:template LOCATION="https://railsbytes.com/script/zJosO5"
```

**From the article**, the two base classes:

```ruby
class ApplicationViewComponent < ViewComponentContrib::Base
  extend Dry::Initializer

  include ApplicationHelper
end
```

```ruby
class ApplicationViewComponentPreview < ViewComponentContrib::Preview::Base
  self.abstract_class = true
  layout "component_preview"
end
```

**This repo** inherits from `ViewComponent::Base` directly and pulls in only the
StyleVariants module, because `ViewComponentContrib::Base` brings
`dry-initializer` with it and a library should not put that in a host's bundle:

```ruby
class ApplicationViewComponent < ViewComponent::Base
  include ViewComponentContrib::StyleVariants

  style_config.postprocess_with { |classes| ShadcnViewComponent.cn(classes) }
end
```

## The `component` helper

**From the article**, so templates do not repeat `render(X::Component.new(…))`:

```ruby
# ApplicationHelper
def component(name, *args, **kwargs, &block)
  component = name.to_s.camelize.constantize::Component
  render(component.new(*args, **kwargs), &block)
end
```

```erb
<%= component "example", title: "Hello World!" %>
```

With relative lookup for nested components:

```ruby
class << self
  def component_name
    @component_name ||= name.sub(/::Component$/, "").underscore
  end
end

def component(name, ...)
  return super unless name.starts_with?(".")

  full_name = self.class.component_name + name.sub('.', '/')

  super(full_name, ...)
end
```

```erb
<%= component ".my-nested-component" %>
```

**This repo does not ship this helper.** A gem cannot define `component` in a
host's `ApplicationHelper` without risking a collision, and `render(...)` with
an explicit class is unambiguous at the call site.

## Sidecar previews and Lookbook

**From the article**, everything down to the preview class:

```ruby
# config/initializers/view_component.rb
ActiveSupport.on_load(:view_component) do
  ViewComponent::Preview.extend ViewComponentContrib::Preview::Sidecarable
  ViewComponent::Preview.extend ViewComponentContrib::Preview::Abstract
end
```

```ruby
gem "lookbook", require: false
```

```ruby
# config/application.rb
config.lookbook_enabled = ENV["LOOKBOOK_ENABLED"] == "true" || Rails.env.development?
require "lookbook" if config.lookbook_enabled
```

```ruby
# config/routes.rb
if Rails.application.config.lookbook_enabled
  mount Lookbook::Engine, at: "/dev/lookbook"
end
```

A preview class, with Lookbook param annotations:

```ruby
class Collapsible::Preview < ApplicationViewComponentPreview
  # @param title text
  def default(title: "What is the goal of this product?")
    render_with(title:)
  end

  # @param title text
  def open(title: "Why is it open already?")
    render_with(title:)
  end
end
```

`default` renders `preview.html.erb`; any other example renders
`previews/<name>.html.erb`.

**This repo** wires the same thing from the engine, so a host gets previews
without configuring anything:

```ruby
initializer "shadcn_view_component.previews" do |app|
  options = app.config.view_component
  options.previews.paths << root.join(COMPONENTS_PATH).to_s

  ActiveSupport.on_load(:view_component) do
    ViewComponent::Preview.extend ViewComponentContrib::Preview::Sidecarable
  end
end
```

**Previews here are load-bearing, not decorative.** `snapshot_spec` and
`accessibility_spec` both read the preview list off disk, so adding a preview
is what puts a component under test. A component without one is invisible to
two suites that will nonetheless pass.

## i18n

**From the article.** One namespace keyed by component path, so the template
never names it:

```yml
en:
  view_components:
    way_down:
      we_go:
        example:
          title: "Hello World!"
```

```erb
<%# app/views/components/way_down/we_go/example/component.html.erb %>
<h1><%= t(".title") %></h1>
```

**This repo** uses a flat `shadcn_view_component.*` namespace with shadcn's
English as the default, so the gem renders untranslated and a host can override
any key:

```ruby
def shadcn_t(key)
  I18n.t("shadcn_view_component.#{key}")
end
```

## Stimulus beside the component

**From the article**, a controller in the component's own directory, registered
from its path:

```js
// app/views/components/hello/controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name"]

  greet() {
    const element = this.nameTarget
    const name = element.value
    console.log(`Hello, ${name}!`)
  }
}
```

```js
const controllers = import.meta.globEager(
  "./../../app/views/components/**/controller.js"
)

for (let path in controllers) {
  let module = controllers[path]
  let name = path
    .match(/app\/views\/components\/(.+)\/controller\.js$/)[1]
    .replaceAll("_", "-")
    .replaceAll("/", "--")

  application.register(name, module.default)
}
```

```ruby
def controller_name
  self.class.identifier
end
```

**This repo** keeps its controllers in one directory and registers them from an
explicit map, because glob-based registration needs a bundler and the gem must
also work under importmap. Adding one means two edits, both in
`app/javascript/shadcn/index.js`:

```js
import AccordionController from "shadcn/controllers/accordion_controller"
// …

const CONTROLLERS = {
  accordion: AccordionController,
  "dropdown-menu": DropdownMenuController,   // kebab-case where the name has two words
  // …
}

export function registerShadcnControllers(application) {
  for (const [ name, controller ] of Object.entries(CONTROLLERS)) {
    application.register(`shadcn--${name}`, controller)
  }

  resyncOnMorph(application)

  return application
}
```

So the component emitting `data-controller="shadcn--accordion"` is matched by
the key `accordion`. No pin is needed — `config/importmap.rb` uses
`pin_all_from`, so a new file under `app/javascript/shadcn` is importable
immediately.

The trade-off is a hand-maintained list, and `stimulus_contract_spec` exists to
catch it drifting: Ruby and JS are wired together by bare strings, so renaming a
controller method would otherwise break every Select in the wild with nothing
failing.

## The query linter

**From the article.** Turn "components must not query" from a convention into a
failure:

```ruby
# config/application.rb
config.view_component.instrumentation_enabled = true
```

```ruby
# config/environments/development.rb, test.rb
config.view_component.raise_on_db_queries = true
```

```ruby
# ApplicationViewComponent — the opt-out
class << self
  attr_accessor :allow_db_queries
  alias_method :allow_db_queries?, :allow_db_queries
end
```

```ruby
# config/initializers/view_component.rb
if Rails.application.config.view_component.raise_on_db_queries
  ActiveSupport::Notifications.subscribe "sql.active_record" do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)

    Thread.current[:last_sql_query] = event
  end

  ActiveSupport::Notifications.subscribe("!render.view_component") do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    last_sql_query = Thread.current[:last_sql_query]
    next unless last_sql_query

    if (event.time..event.end).cover?(last_sql_query.time)
      component = event.payload[:name].constantize
      next if component.allow_db_queries?

      raise <<~ERROR.squish
        `#{component.component_name}` component is not allowed to make database queries.
        Attempting to make the following query: #{last_sql_query.payload[:sql]}.
      ERROR
    end
  end
end
```

Note the shape: an opt-out on the class, not an opt-in, so the default is the
safe one and every exception is written down.

**Not relevant to this repo** — it has no ActiveRecord at all — but it is the
right thing to reach for in an application built on these components.
