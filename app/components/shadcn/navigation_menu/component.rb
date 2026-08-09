# frozen_string_literal: true

module Shadcn
  module NavigationMenu
    # Port of registry/new-york-v4/ui/navigation-menu.tsx, whose behaviour is
    # Radix's `NavigationMenu` — 1,403 lines against shadcn's 168, vendored at
    # `vendor/radix/ui/navigation-menu.tsx`.
    #
    # **`data-viewport` is always `false` here, and that is the decision this
    # port turns on.** Upstream's default renders every panel into one shared
    # box that animates between their sizes — measured on the live demo, the
    # content's parent is `navigation-menu-viewport`, which means React has
    # moved it there through a portal. Nothing is portalled in this gem, for the
    # reason in decisions/02-javascript.md, so that mode cannot be reproduced
    # without giving up the rule every other component here was built on.
    #
    # `viewport={false}` is not a workaround: it is a configuration shadcn
    # supports and ships classes for, and in it each panel stays inside its own
    # item with its own border, background and shadow. See
    # features/navigation-menu.md.
    class Component < ApplicationViewComponent
      slot_name :"navigation-menu"

      style do
        base {
          "group/navigation-menu relative flex max-w-max flex-1 items-center justify-center"
        }
      end

      attr_reader :delay_duration, :skip_delay_duration

      # Radix's own defaults (navigation-menu.tsx:136-137). `skip_delay_duration`
      # is the grace period after a panel closes in which the next one opens at
      # once — it is what stops a menu feeling sticky when you sweep across it.
      def initialize(delay_duration: 200, skip_delay_duration: 300, **attributes)
        @delay_duration = delay_duration
        @skip_delay_duration = skip_delay_duration
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          "data-viewport" => "false",
          "data-controller" => "shadcn--navigation-menu",
          "data-shadcn--navigation-menu-delay-value" => delay_duration,
          "data-shadcn--navigation-menu-skip-delay-value" => skip_delay_duration
        }.merge(defaults))
      end
    end
  end
end
