# frozen_string_literal: true

module Shadcn
  module NavigationMenu
    module Trigger
      # The button that opens a panel. Its classes are exported upstream as
      # `navigationMenuTriggerStyle` so a plain link can borrow them; the same
      # is available here as `Component.new.css_classes`, which is how the
      # sidebar preview borrows the menu button's.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"navigation-menu-trigger"

        style do
          base {
            "group inline-flex h-9 w-max items-center justify-center rounded-md " \
            "bg-background px-4 py-2 text-sm font-medium transition-[color,box-shadow] " \
            "outline-none hover:bg-accent hover:text-accent-foreground " \
            "focus:bg-accent focus:text-accent-foreground focus-visible:ring-[3px] " \
            "focus-visible:ring-ring/50 focus-visible:outline-1 " \
            "disabled:pointer-events-none disabled:opacity-50 " \
            "data-[state=open]:bg-accent/50 data-[state=open]:text-accent-foreground " \
            "data-[state=open]:hover:bg-accent data-[state=open]:focus:bg-accent"
          }
        end

        def element_attributes(**defaults)
          super(**{
            type: "button",
            "data-state" => "closed",
            "aria-expanded" => "false",
            "data-shadcn--navigation-menu-target" => "trigger",
            "data-action" => "pointerenter->shadcn--navigation-menu#pointerEnter " \
                             "pointerleave->shadcn--navigation-menu#pointerLeave " \
                             "click->shadcn--navigation-menu#toggle " \
                             "keydown->shadcn--navigation-menu#keydown"
          }.merge(defaults))
        end

        # The chevron is upstream's, and so is the space before it: shadcn
        # writes `{children}{" "}` rather than a gap utility (navigation-menu.tsx:76).
        def call
          render_element(
            body: safe_join([
              content,
              " ",
              render(Shadcn::Icon::Component.new(
                "chevron-down",
                class: "relative top-[1px] ml-1 size-3 transition duration-300 " \
                       "group-data-[state=open]:rotate-180",
                "aria-hidden": true
              ))
            ])
          )
        end
      end
    end
  end
end
