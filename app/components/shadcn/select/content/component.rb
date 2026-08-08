# frozen_string_literal: true

module Shadcn
  module Select
    module Content
      # SelectContent — the viewport and the two scroll buttons are part of the
      # markup shadcn emits, so they are reproduced here.
      class Component < ApplicationViewComponent
        # `shrink-0` mirrors the `flexShrink: 0` Radix sets inline
        # (vendor/radix/ui/select.tsx:1691): the buttons keep their height while
        # the viewport takes the rest, which is what pins them to the edges.
        SCROLL_BUTTON_CLASSES = "flex shrink-0 cursor-default items-center justify-center py-1"

        renders_many :items, "Shadcn::Select::Item::Component"

        slot_name :"select-content"

        style do
          base {
            "relative z-50 flex flex-col max-h-(--radix-select-content-available-height) min-w-[8rem] " \
            "origin-(--radix-select-content-transform-origin) overflow-x-hidden " \
            "overflow-y-auto rounded-md border bg-popover text-popover-foreground shadow-md " \
            "data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 " \
            "data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 " \
            "data-[state=closed]:animate-out data-[state=closed]:fade-out-0 " \
            "data-[state=closed]:zoom-out-95 data-[state=open]:animate-in " \
            "data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
          }

          variants {
            position {
              popper {
                "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 " \
                "data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1"
              }
              send(:"item-aligned") { "" }
            }
          }

          defaults { { position: :"item-aligned" } }
        end

        attr_reader :position, :searchable

        def initialize(position: :"item-aligned", searchable: false, **attributes)
          @position = position&.to_sym || :"item-aligned"
          @searchable = searchable
          super(**attributes)
        end

        def style_variants
          { position: }
        end

        def element_attributes(**defaults)
          super(**{
            # A searchable popover holds a text field *and* a list, so it
            # cannot be the list: a textbox is not an allowed child of a
            # listbox. The role moves to Select::List and this becomes the
            # dialog that contains both, which is what axe accepts and what
            # shadcn's aria variant emits.
            role: (searchable ? "dialog" : "listbox"),
            "aria-label" => (shadcn_t("select.dialog_label") if searchable),
            tabindex: "-1",
            "data-state" => "closed",
            hidden: true,
            "data-shadcn--select-target" => "content",
            # `scroll` does not bubble, but Stimulus binds the action to this
            # element itself, so it fires. Which element actually scrolls
            # differs by mode — see the controller's `scrollContainer`.
            "data-action" => "keydown->shadcn--select#contentKeydown"
          }.merge(defaults))
        end

        def call
          render_element(body: safe_join([
            scroll_button("select-scroll-up-button", "chevron-up", "scrollUpButton"),
            viewport,
            scroll_button("select-scroll-down-button", "chevron-down", "scrollDownButton")
          ]))
        end

        private

        def viewport
          tag.div(
            searchable ? searchable_body : options,
            class: viewport_classes,
            "data-shadcn--select-target": "viewport",
            # `scroll` does not bubble, but Stimulus binds to this element
            # itself, so it fires. In a searchable panel the list scrolls
            # instead and carries its own copy of this action.
            "data-action": "scroll->shadcn--select#syncScrollButtons"
          )
        end

        # The field is pinned and the list scrolls under it, rather than the
        # whole popover scrolling and taking the field with it.
        def searchable_body
          safe_join([
            render(Search::Component.new),
            render(List::Component.new) { options },
            render(Empty::Component.new)
          ])
        end

        def options
          safe_join([ items, content ].flatten.compact)
        end

        # Radix puts the scrolling here, not on the content: `position: relative`
        # so an item's offsetTop is measured against the viewport rather than
        # the scroll-up button, `flex: 1` to take the space the buttons leave,
        # and `overflow: hidden auto` (vendor/radix/ui/select.tsx:1240-1247).
        # Without it the content scrolled and carried the buttons out of sight
        # with the options — see decisions/04-bugs-fixed.md.
        VIEWPORT_CLASSES = "relative flex-1 overflow-x-hidden overflow-y-auto"

        def viewport_classes
          # A searchable panel pins its search field, so the scrolling moves one
          # level further in, onto the list.
          return ShadcnViewComponent.cn("relative flex-1 flex flex-col overflow-hidden") if searchable

          extra =
            if position == :popper
              "h-[var(--radix-select-trigger-height)] w-full " \
              "min-w-[var(--radix-select-trigger-width)] scroll-my-1"
            end

          ShadcnViewComponent.cn(VIEWPORT_CLASSES, "p-1", extra)
        end

        # Radix mounts these only while there is somewhere to scroll and
        # unmounts them otherwise (vendor/radix/ui/select.tsx:1594, :1642).
        # Rendered hidden here instead, which is this gem's convention for the
        # same thing — see decisions/02-javascript.md, "Indicators are rendered
        # hidden, not omitted" — so the controller only toggles a flag.
        #
        # `aria-hidden` because they are a pointer affordance: the keyboard
        # scrolls by moving the highlight (vendor/radix/ui/select.tsx:1691).
        def scroll_button(slot, icon, target)
          tag.div(
            render(Icon::Component.new(icon, class: "size-4")),
            "data-slot": slot,
            "aria-hidden": true,
            hidden: true,
            "data-shadcn--select-target": target,
            "data-action": "pointerdown->shadcn--select#startAutoScroll " \
                           "pointermove->shadcn--select#startAutoScroll " \
                           "pointerleave->shadcn--select#stopAutoScroll",
            class: SCROLL_BUTTON_CLASSES
          )
        end
      end
    end
  end
end
