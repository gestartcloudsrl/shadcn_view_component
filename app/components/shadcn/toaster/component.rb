# frozen_string_literal: true

module Shadcn
  module Toaster
    # Ours, not a port — and the distinction matters more here than anywhere
    # else in this gem.
    #
    # `sonner.tsx` is forty lines and emits no `data-slot` at all: a theme, five
    # icons and four custom properties handed to the `sonner` package, which
    # supplies every element and every rule — 1,601 lines of TypeScript and 729
    # of CSS. There is no upstream markup here to be 1:1 with, so `parity_spec`
    # has nothing to check and this component's shape is this port's own.
    #
    # What is kept from upstream is what can be: sonner's measurements, read
    # from its stylesheet — 356px wide, 14px between, 24px from the edge, four
    # seconds of life — and the four colours `sonner.tsx` itself chooses, which
    # are the popover's.
    #
    # And the way in is Rails': a toast is a component, so the server can raise
    # one. Three routes, in order of how much an app will use them —
    #
    #   flash            `Toaster::Component.new(flash:)` turns each into a toast
    #   turbo_stream     `turbo_stream.append "shadcn-toasts", …` onto this list
    #   javascript       `document.dispatchEvent(new CustomEvent("shadcn--toast", …))`
    #
    # — where sonner has only the third. See features/toaster.md.
    class Component < ApplicationViewComponent
      POSITIONS = {
        "top-left" => "top-6 left-6 items-start",
        "top-center" => "top-6 left-1/2 -translate-x-1/2 items-center",
        "top-right" => "top-6 right-6 items-end",
        "bottom-left" => "bottom-6 left-6 items-start",
        "bottom-center" => "bottom-6 left-1/2 -translate-x-1/2 items-center",
        "bottom-right" => "bottom-6 right-6 items-end"
      }.freeze

      # sonner's own, so a caller who has read its docs is not surprised.
      DEFAULT_DURATION = 4000

      renders_many :toasts, "Shadcn::Toaster::Toast::Component"

      # A `<section>`, as sonner renders (index.tsx:788): `aria-label` on a bare
      # `<div>` is prohibited ARIA — a label needs a role to belong to, and a
      # section is the landmark that has one.
      default_tag :section
      slot_name :toaster

      attr_reader :position, :duration, :list_id, :flash

      def initialize(position: "bottom-right", duration: DEFAULT_DURATION,
                     list_id: "shadcn-toasts", flash: nil, **attributes)
        @position = POSITIONS.key?(position.to_s) ? position.to_s : "bottom-right"
        @duration = duration
        @list_id = list_id
        @flash = flash
        super(**attributes)
      end

      def element_attributes(**defaults)
        super(**{
          class: "group/toaster pointer-events-none fixed z-[100] flex " \
                 "#{POSITIONS.fetch(position)}",
          "aria-live" => "polite",
          # sonner's own (index.tsx:792): each toast is read on its own, not as
          # a re-reading of the whole stack every time one arrives.
          "aria-atomic" => "false",
          "aria-label" => shadcn_t("toaster.label"),
          "data-position" => position,
          "data-controller" => "shadcn--toaster",
          "data-shadcn--toaster-duration-value" => duration,
          "data-action" => "shadcn--toast@document->shadcn--toaster#raise"
        }.merge(defaults))
      end

      def call
        render_element(body: safe_join([ list, template ]))
      end

      private

      # The element a `turbo_stream.append` aims at, which is why it has an id
      # by default and why the id is an argument rather than generated.
      def list
        tag.ol(safe_join([ flash_toasts, toasts, content ].flatten.compact),
               id: list_id,
               # The stack, and it is a stack rather than a column: the toasts
               # are absolutely placed inside this box and the controller writes
               # where each one sits. `w-[356px]` is sonner's width, and the
               # height is the controller's — it is what the pointer has to be
               # inside for the stack to open.
               # No transition on the height, and that is deliberate: this box is
               # the area a pointer has to be inside for the stack to stay open,
               # and an area that arrives four hundred milliseconds late is an
               # area that is wrong while it matters. The toasts animate; the
               # box they are in does not. Measured in a browser that runs no
               # animation frames, a transition here left it at zero for good.
               class: "relative w-[356px] max-w-[calc(100vw-2rem)]",
               "data-shadcn--toaster-target": "list",
               "data-action": "pointerenter->shadcn--toaster#hold " \
                              "pointerleave->shadcn--toaster#release " \
                              "focusin->shadcn--toaster#hold " \
                              "focusout->shadcn--toaster#release")
      end

      # Rails' own flash, rendered with the page. `:notice` and `:alert` are the
      # two `redirect_to` sets without being asked, so they are mapped rather
      # than left to be configured.
      FLASH_VARIANTS = { "notice" => :success, "alert" => :error, "error" => :error,
                        "warning" => :warning, "info" => :info }.freeze

      def flash_toasts
        return [] if flash.blank?

        flash.map do |key, message|
          next if message.blank?

          render(Toast::Component.new(title: message, variant: FLASH_VARIANTS.fetch(key.to_s, :default)))
        end.compact
      end

      # The shapes the JavaScript route clones — one per variant, because a
      # variant is not only an attribute: `success` has an icon and `default`
      # has none, and no attribute set afterwards can conjure an element that
      # was never rendered. That is what the first version of this did, and the
      # toasts it made came out blank-faced.
      #
      # Rendered in Ruby so the class strings live in one place. A controller
      # that builds this markup from string literals is a second copy of every
      # class in this file, kept in step by hand.
      def template
        safe_join(Toast::Component::VARIANTS.keys.map { |variant|
          tag.template("data-shadcn--toaster-target": "template", "data-variant": variant) do
            render(Toast::Component.new(title: "", description: "", variant:))
          end
        })
      end
    end
  end
end
