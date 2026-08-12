# frozen_string_literal: true

module Shadcn
  module Carousel
    module Previous
      # CarouselPrevious — the button's own variants, as `pagination-link` takes
      # them: upstream renders a `<Button variant="outline" size="icon">` and
      # adds its placement on top, so the classes come from
      # `Button.variant_classes` rather than from a style block of this
      # component's own. Redefining `style` here would *replace* the button's
      # base rather than add to it, which is a round control with no round.
      class Component < ApplicationViewComponent
        default_tag :button
        slot_name :"carousel-previous"

        PLACEMENT = {
          horizontal: "top-1/2 -left-12 -translate-y-1/2",
          vertical: "-top-12 left-1/2 -translate-x-1/2 rotate-90"
        }.freeze

        attr_reader :orientation, :variant, :size

        def initialize(orientation: :horizontal, variant: :outline, size: :icon, **attributes)
          @orientation = orientation&.to_sym == :vertical ? :vertical : :horizontal
          @variant = variant&.to_sym || :outline
          @size = size&.to_sym || :icon
          super(**attributes)
        end

        # Disabled until the controller says otherwise: at rest a carousel is at
        # one end, and which end has room is a question about a viewport the
        # server has never measured.
        def element_attributes(**defaults)
          super(**{
            type: "button",
            disabled: true,
            "data-shadcn--carousel-target" => "previous",
            "data-action" => "click->shadcn--carousel#previous"
          }.merge(defaults))
        end

        def css_classes(extra = nil)
          Button::Component.variant_classes(
            variant:,
            size:,
            class: [ "absolute size-8 rounded-full", PLACEMENT.fetch(orientation), extra ].compact.join(" ")
          )
        end

        def call
          render_element(body: safe_join([
            render(Icon::Component.new("arrow-left")),
            tag.span(shadcn_t("carousel.previous"), class: "sr-only")
          ]))
        end
      end
    end
  end
end
