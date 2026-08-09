# frozen_string_literal: true

module Shadcn
  module MessageScroller
    module Button
      # The floating "jump to the end" control, and its start-side twin.
      #
      # A Button with different defaults — `secondary`, `icon-sm` — plus the
      # positioning and the transition, so it subclasses rather than being
      # declared with `part … from:`, which restamps the slot and leaves the
      # arguments alone.
      #
      # `data-active` is the controller's to write and decides everything
      # visible: the button is not hidden when there is nowhere to scroll, it is
      # scaled, faded and pushed off its edge, with a slower easing on the way
      # out than on the way in. Rendered `false` so it starts out of sight
      # without a frame of flicker before the controller connects.
      class Component < Shadcn::Button::Component
        slot_name :"message-scroller-button"

        style do
          base {
            "absolute inset-s-1/2 -translate-x-1/2 border-border bg-background " \
            "text-foreground transition-[translate,scale,opacity] duration-200 " \
            "hover:bg-muted hover:text-foreground " \
            "data-[active=false]:pointer-events-none data-[active=false]:scale-95 " \
            "data-[active=false]:opacity-0 data-[active=false]:duration-400 " \
            "data-[active=false]:ease-[cubic-bezier(0.7,0,0.84,0)] " \
            "data-[active=true]:translate-y-0 data-[active=true]:scale-100 " \
            "data-[active=true]:opacity-100 " \
            "data-[active=true]:ease-[cubic-bezier(0.23,1,0.32,1)] " \
            "data-[direction=end]:bottom-4 " \
            "data-[direction=end]:data-[active=false]:translate-y-full " \
            "data-[direction=start]:top-4 " \
            "data-[direction=start]:data-[active=false]:-translate-y-full " \
            "rtl:translate-x-1/2 data-[direction=start]:[&_svg]:rotate-180"
          }
        end

        attr_reader :direction

        def initialize(direction: :end, variant: :secondary, size: :"icon-sm", **attributes)
          @direction = direction&.to_sym || :end
          super(variant:, size:, **attributes)
        end

        def element_attributes(**defaults)
          super(**{
            "data-direction" => direction,
            "data-active" => "false",
            # Out of the tab order while there is nowhere to scroll, as the
            # primitive does (components.tsx:400). It is invisible and
            # `pointer-events-none` in that state, so leaving it tabbable would
            # give a keyboard a stop that a pointer does not have.
            tabindex: -1,
            "data-shadcn--message-scroller-target" => "button",
            "data-action" => "shadcn--message-scroller#jump"
          }.merge(defaults))
        end

        # The chevron and its name. Upstream renders one arrow and rotates it for
        # the start direction (message-scroller.tsx:108-115), which is why there
        # is one icon here and a `rotate-180` in the classes above.
        def call
          return render_element(body: content) if content.present?

          render_element(
            body: safe_join([
              render(Shadcn::Icon::Component.new("chevron-down")),
              tag.span(shadcn_t("message_scroller.#{direction == :end ? 'scroll_to_end' : 'scroll_to_start'}"),
                       class: "sr-only")
            ])
          )
        end
      end
    end
  end
end
