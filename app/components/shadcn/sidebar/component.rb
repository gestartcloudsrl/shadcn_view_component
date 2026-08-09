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

        render_element(body: safe_join([ gap, container ]))
      end

      private

      def bare? = collapsible == :none

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
          inset_like? ? floating : plain
        )
      end

      def container
        tag.div(inner, "data-slot": "sidebar-container", class: container_classes)
      end

      def container_classes
        ShadcnViewComponent.cn(
          "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) " \
          "transition-[left,right,width] duration-200 ease-linear md:flex",
          side_classes,
          padding_classes
        )
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
