# frozen_string_literal: true

module Shadcn
  module Sidebar
    # The panel itself — upstream's `Sidebar` (vendor/shadcn/ui/sidebar.tsx:154),
    # not its provider, which is `Sidebar::Provider::Component`.
    #
    # Upstream renders three different trees here and picks between them while
    # rendering. Two of those choices are knowable on a server and one is not:
    #
    #   collapsible: :none  a bare panel, decided here
    #   isMobile            a Sheet, decided by `matchMedia` — so not here
    #
    # The mobile branch is the controller's, applied to this same DOM without
    # moving it. See decisions/02-javascript.md.
    class Component < ApplicationViewComponent
      slot_name :sidebar

      style do
        base { "group peer hidden text-sidebar-foreground md:block" }
      end

      attr_reader :side, :variant, :collapsible

      def initialize(side: :left, variant: :sidebar, collapsible: :offcanvas, **attributes)
        @side = side&.to_sym || :left
        @variant = variant&.to_sym || :sidebar
        @collapsible = collapsible&.to_sym || :offcanvas
        super(**attributes)
      end

      def element_attributes(**defaults)
        return super(**defaults) if bare?

        super(**{
          "data-shadcn--sidebar-target" => "sidebar",
          "data-state" => "expanded",
          # Upstream fills this only while collapsed (sidebar.tsx:212) — the
          # classes match `group-data-[collapsible=offcanvas]:…`, so a value here
          # while expanded would style an open panel as a closed one. The value
          # to collapse *to* therefore has to live somewhere else.
          "data-collapsible" => "",
          "data-sidebar-collapsible" => collapsible,
          "data-variant" => variant,
          "data-side" => side
        }.merge(defaults))
      end

      # `collapsible: :none` is a different element with different classes, not
      # the same one with a flag (sidebar.tsx:166-180).
      def css_classes(extra = nil)
        return super if !bare?

        ShadcnViewComponent.cn(
          "flex h-full w-(--sidebar-width) flex-col bg-sidebar text-sidebar-foreground", extra
        )
      end

      def call
        return render_element(body: content) if bare?

        render_element(body: safe_join([ overlay, gap, container ]))
      end

      private

      def bare? = collapsible == :none

      # The dimmed backdrop upstream gets for free by rendering a real `Sheet`
      # below `md` (sidebar.tsx:184). There is no Sheet here — this panel *is*
      # the sheet — so the element it would have portalled has to be in the
      # markup, hidden, from the start. It is the gem's own `sheet-overlay`,
      # classes and all, rather than a new slot: a host styling `sheet-overlay`
      # should reach this one too.
      #
      # `hidden` until the controller opens the sheet, and it stays in the
      # server's markup on desktop, where nothing ever unhides it. The dialog
      # target it inherits is cleared: this one answers to the sidebar.
      def overlay
        render(
          Shadcn::Sheet::Overlay::Component.new(
            "data-shadcn--dialog-target": nil,
            "data-shadcn--sidebar-target": "overlay"
          )
        )
      end

      def gap
        tag.div("data-slot": "sidebar-gap", class: gap_classes)
      end

      def gap_classes
        floating = "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]"
        plain = "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"

        ShadcnViewComponent.cn(
          "relative w-(--sidebar-width) bg-transparent transition-[width] duration-200 ease-linear",
          "group-data-[collapsible=offcanvas]:w-0",
          "group-data-[side=right]:rotate-180",
          inset_like? ? floating : plain,
          # This element exists to reserve the panel's width in the page's flow.
          # A sheet overlays the page instead, so on the mobile branch it has to
          # reserve nothing. The Popover API already takes the panel out of flow
          # while the sheet is open, which makes this redundant there and load
          # -bearing everywhere else: `top_layer.js` is feature-detected, and the
          # fallback leaves the panel in flow.
          "group-data-[mobile=true]:w-0"
        )
      end

      def container
        tag.div(
          inner,
          "data-slot": "sidebar-container",
          # The element that animates, so the controller has to be able to write
          # `data-state` on it and wait for its animations to settle.
          "data-shadcn--sidebar-target": "container",
          class: container_classes
        )
      end

      def container_classes
        ShadcnViewComponent.cn(
          "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) " \
          "transition-[left,right,width] duration-200 ease-linear md:flex",
          side_classes,
          padding_classes,
          # Upstream renders a Sheet below `md` and this panel above it, so its
          # `hidden … md:flex` is never asked to show anything on a phone. Here
          # there is one tree and the sheet *is* this element, so the mobile
          # branch has to turn both of those off. The controller does that for
          # the panel's own `hidden … md:block`; nothing was doing it for the
          # container inside, which is why the sheet opened onto an empty strip.
          #
          # A `group-data-` variant rather than the inline `display` used on the
          # panel: both are two-class selectors, so they outrank `md:flex` at
          # every width without the specificity fight a bare class would lose.
          "group-data-[mobile=true]:flex group-data-[mobile=true]:w-(--sidebar-width-mobile)",
          # `z-50` and `shadow-lg` are `sheet-content`'s (sheet.tsx:63), and the
          # overlay above carries `z-50` too — so the two match upstream's pair
          # and DOM order decides, which puts the panel over its own backdrop.
          # The desktop `z-10` would put it under.
          "group-data-[mobile=true]:z-50 group-data-[mobile=true]:shadow-lg",
          sheet_animation_classes
        )
      end

      # `sheet-content`'s own entrance and exit (sheet.tsx:63-68), keyed the way
      # upstream keys them: on the element's *own* `data-state`, which the
      # controller writes only on the mobile branch. On desktop the attribute is
      # absent, so none of this matches and the panel keeps sliding on the
      # `transition-[left,right,width]` above instead.
      #
      # The panel's `data-state` is a different axis — expanded or collapsed —
      # which is why this one is on the container rather than up there.
      def sheet_animation_classes
        slide =
          if side == :left
            "data-[state=open]:slide-in-from-left data-[state=closed]:slide-out-to-left"
          else
            "data-[state=open]:slide-in-from-right data-[state=closed]:slide-out-to-right"
          end

        "data-[state=open]:animate-in data-[state=closed]:animate-out " \
        "data-[state=open]:duration-500 data-[state=closed]:duration-300 #{slide}"
      end

      def side_classes
        if side == :left
          "left-0 group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)]"
        else
          "right-0 group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)]"
        end
      end

      def padding_classes
        if inset_like?
          "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]"
        else
          "group-data-[collapsible=icon]:w-(--sidebar-width-icon) " \
          "group-data-[side=left]:border-r group-data-[side=right]:border-l"
        end
      end

      def inner
        tag.div(
          content,
          "data-sidebar": "sidebar",
          "data-slot": "sidebar-inner",
          class: "flex h-full w-full flex-col bg-sidebar " \
                 "group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:border " \
                 "group-data-[variant=floating]:border-sidebar-border " \
                 "group-data-[variant=floating]:shadow-sm"
        )
      end

      def inset_like? = [ :floating, :inset ].include?(variant)
    end
  end
end
